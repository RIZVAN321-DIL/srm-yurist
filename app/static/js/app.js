const App = {
    csrfToken: '', user: null, currentTab: 'dashboard',
    modules: {
        dashboard: DashboardModule,
        clients: clientsModule,
        cases: casesModule,
        users: usersModule,
        finance: financeModule
    },
    async api(url, options = {}) {
        const headers = { ...options.headers, 'X-CSRF-Token': App.csrfToken };
        const res = await fetch(url, { ...options, headers, credentials: 'include' });
        if (res.status === 401) { App.logout(); throw new Error('Unauthorized'); }
        if (res.status === 423) { alert('Аккаунт заблокирован.'); throw new Error('Locked'); }
        if (res.status === 500) { alert('Ошибка сервера. Попробуйте позже.'); throw new Error('ServerError'); }
        if (!res.ok) { const d = await res.json().catch(()=>({})); throw new Error(d.detail || 'Ошибка'); }
        return res.json();
    },
    async doLogin() {
        const login = document.getElementById('loginInput').value, password = document.getElementById('passInput').value;
        document.getElementById('loginError').textContent = '';
        try {
            const res = await fetch('/api/auth/login', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({login,password})});
            const data = await res.json();
            if (data.ok) {
                App.csrfToken = data.csrf_token; App.user = data.user;
                document.getElementById('loginOverlay').style.display = 'none';
                document.getElementById('appLayout').style.display = 'flex';
                App.renderSidebar();
                if (data.user.force_password_change) App.showPasswordChange(); else App.showTab('dashboard');
            } else { document.getElementById('loginError').textContent = data.detail || 'Ошибка входа'; }
        } catch (e) { document.getElementById('loginError').textContent = 'Ошибка соединения'; }
    },
    async logout() { await fetch('/api/auth/logout', {method:'POST',credentials:'include'}); App.csrfToken=''; App.user=null; document.getElementById('loginOverlay').style.display='flex'; document.getElementById('appLayout').style.display='none'; },
    showPasswordChange() {
        document.getElementById('modal').classList.add('active');
        document.getElementById('modal-content').innerHTML = `<h2>Смена пароля</h2><p style="color:var(--danger);margin-bottom:16px">Перед началом работы необходимо сменить пароль.</p><div class="form-group"><label>Старый пароль</label><input id="oldpw" type="password" value="admin123"></div><div class="form-group"><label>Новый пароль (мин. 6 символов)</label><input id="newpw" type="password" minlength="6"></div><div class="form-group"><label>Повторите пароль</label><input id="newpw2" type="password" minlength="6"></div><button class="btn btn-success" style="width:100%" onclick="App.changePassword()">Сменить</button><div class="login-error" id="pwError" style="margin-top:12px"></div>`;
    },
    async changePassword() {
        const old=document.getElementById('oldpw').value, n1=document.getElementById('newpw').value, n2=document.getElementById('newpw2').value;
        if (n1.length<6) { document.getElementById('pwError').textContent='Пароль должен быть не менее 6 символов'; return; }
        if (n1!==n2) { document.getElementById('pwError').textContent='Пароли не совпадают'; return; }
        const res = await App.api('/api/auth/change-password', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({old_password:old,new_password:n1})});
        if (res.ok) { App.closeModal(); App.user.force_password_change=false; App.showTab('dashboard'); alert('Пароль изменён!'); }
    },
    renderSidebar() {
        const menu = [{id:'dashboard',icon:'📊',label:'Дашборд'},{id:'clients',icon:'👥',label:'Клиенты'},{id:'cases',icon:'📁',label:'Дела'},{id:'users',icon:'👨‍💼',label:'Сотрудники',admin:true},{id:'finance',icon:'💰',label:'Финансы',admin:true}];
        let html = '<h2>⚖️ CRM Юрист</h2>';
        menu.forEach(item => { if (item.admin && App.user?.role !== 'admin') return; html += `<a class="${App.currentTab===item.id?'active':''}" onclick="App.showTab('${item.id}')">${item.icon} ${item.label}</a>`; });
        html += '<button class="logout-btn" onclick="App.logout()" style="margin-top:auto">🚪 Выйти</button>';
        document.getElementById('sidebar').innerHTML = html;
    },
    async showTab(tab) {
        App.currentTab = tab;
        App.renderSidebar();
        document.getElementById('table-container').innerHTML = '';
        const module = App.modules[tab];
        if (module && module.load) {
            await module.load();
        } else {
            await DashboardModule.load();
        }
    },
    toggleTheme() { document.body.classList.toggle('dark'); localStorage.setItem('crm_theme', document.body.classList.contains('dark')?'dark':'light'); },
    closeModal() { document.getElementById('modal').classList.remove('active'); },
    text(str) { const div=document.createElement('div'); div.appendChild(document.createTextNode(str||'')); return div.innerHTML; }
};
if (localStorage.getItem('crm_theme')==='dark') document.body.classList.add('dark');
