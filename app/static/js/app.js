const App = {
    csrfToken: '',
    user: null,
    currentPage: 'dashboard',

    // ========== API ==========
    async api(url, options = {}) {
        const headers = { ...options.headers, 'X-CSRF-Token': App.csrfToken };
        const res = await fetch(url, { ...options, headers, credentials: 'include' });
        if (res.status === 401) { App.logout(); throw new Error('Unauthorized'); }
        if (res.status === 423) { alert('Аккаунт заблокирован на 15 минут.'); throw new Error('Locked'); }
        if (!res.ok) {
            const d = await res.json().catch(() => ({}));
            throw new Error(d.detail || 'Ошибка сервера');
        }
        return res.json();
    },

    // ========== AUTH ==========
    async doLogin() {
        const login = document.getElementById('loginInput').value.trim();
        const password = document.getElementById('passInput').value;
        const errEl = document.getElementById('loginError');
        errEl.textContent = '';
        if (!login || !password) { errEl.textContent = 'Введите логин и пароль'; return; }
        try {
            const res = await fetch('/api/auth/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ login, password })
            });
            const data = await res.json();
            if (!data.ok) { errEl.textContent = data.detail || 'Ошибка входа'; return; }
            App.csrfToken = data.csrf_token;
            App.user = data.user;
            document.getElementById('loginOverlay').style.display = 'none';
            document.getElementById('appLayout').style.display = 'flex';
            if (data.user.force_password_change) { App.showPasswordChange(); }
            else { App.updateSidebar(); App.navigate('dashboard'); }
        } catch (e) { errEl.textContent = 'Ошибка соединения с сервером'; }
    },

    async logout() {
        try { await fetch('/api/auth/logout', { method: 'POST', credentials: 'include' }); } catch (e) {}
        App.csrfToken = ''; App.user = null;
        document.getElementById('loginOverlay').style.display = 'flex';
        document.getElementById('appLayout').style.display = 'none';
    },

    showPasswordChange() {
        App.openModal('🔒 Смена пароля', `
            <p style="color:var(--danger);margin-bottom:18px;font-weight:600;">
                ⚠️ Перед началом работы необходимо сменить пароль.
            </p>
            <div class="form-group"><label>Старый пароль</label><input id="oldpw" type="password" value="admin123"></div>
            <div class="form-group"><label>Новый пароль (мин. 6 символов)</label><input id="newpw" type="password" minlength="6"></div>
            <div class="form-group"><label>Повторите пароль</label><input id="newpw2" type="password" minlength="6"></div>
            <div id="pwError" style="color:var(--danger);font-size:13px;margin-top:8px;"></div>
            <div class="form-actions">
                <button class="btn btn-accent" onclick="App.changePassword()">Сменить пароль</button>
            </div>
        `);
    },

    async changePassword() {
        const old = document.getElementById('oldpw').value;
        const n1 = document.getElementById('newpw').value;
        const n2 = document.getElementById('newpw2').value;
        const errEl = document.getElementById('pwError');
        if (n1.length < 6) { errEl.textContent = 'Пароль должен быть не менее 6 символов'; return; }
        if (n1 !== n2) { errEl.textContent = 'Пароли не совпадают'; return; }
        try {
            const res = await App.api('/api/auth/change-password', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ old_password: old, new_password: n1 })
            });
            if (res.ok) {
                App.closeModal();
                App.user.force_password_change = false;
                App.navigate('dashboard');
                alert('✅ Пароль успешно изменён!');
            }
        } catch (e) { errEl.textContent = e.message; }
    },

    // ========== NAVIGATION ==========
    updateSidebar() {
        document.querySelectorAll('.sidebar a[data-nav]').forEach(a => {
            a.classList.remove('active');
            if (a.dataset.nav === App.currentPage) a.classList.add('active');
        });
        const addBtn = document.getElementById('globalAddBtn');
        const showAdd = ['clients', 'cases', 'users', 'finance'].includes(App.currentPage);
        addBtn.style.display = showAdd ? 'inline-flex' : 'none';
        const titles = {
            dashboard: '📊 Дашборд', clients: '👥 Клиенты', cases: '📁 Дела',
            users: '👤 Сотрудники', finance: '💰 Финансы'
        };
        document.getElementById('pageTitle').textContent = titles[App.currentPage] || 'CRM';
        const now = new Date();
        document.getElementById('pageDate').textContent = now.toLocaleDateString('ru-RU', {
            weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
        });
    },

    navigate(page) {
        App.currentPage = page;
        App.updateSidebar();
        document.getElementById('statsRow').innerHTML = '';
        document.getElementById('contentArea').innerHTML = '<div class="content-card"><p>Загрузка...</p></div>';
        switch (page) {
            case 'dashboard': App.loadDashboard(); break;
            case 'clients': App.loadClients(); break;
            case 'cases': App.loadCases(); break;
            case 'users': App.loadUsers(); break;
            case 'finance': App.loadFinance(); break;
            default: App.loadDashboard();
        }
    },

    handleGlobalAdd() {
        switch (App.currentPage) {
            case 'clients': App.showClientForm(); break;
            case 'cases': App.showCaseForm(); break;
            case 'users': App.showUserForm(); break;
            case 'finance': App.showPaymentForm(); break;
        }
    },

    // ========== DASHBOARD ==========
    async loadDashboard() {
        try {
            const stats = await App.api('/api/dashboard/stats');
            document.getElementById('statsRow').innerHTML = `
                <div class="stat-card accent">
                    <span class="stat-icon">👥</span>
                    <div class="stat-value">${stats.total_clients || 0}</div>
                    <div class="stat-label">Всего клиентов</div>
                </div>
                <div class="stat-card info">
                    <span class="stat-icon">📁</span>
                    <div class="stat-value">${stats.total_cases || 0}</div>
                    <div class="stat-label">Всего дел</div>
                </div>
                <div class="stat-card warning">
                    <span class="stat-icon">⚡</span>
                    <div class="stat-value">${stats.active_cases || 0}</div>
                    <div class="stat-label">Активных дел</div>
                </div>
                <div class="stat-card success">
                    <span class="stat-icon">✅</span>
                    <div class="stat-value">${stats.closed_cases || 0}</div>
                    <div class="stat-label">Закрытых дел</div>
                </div>
            `;
            document.getElementById('contentArea').innerHTML = `
                <div class="content-card">
                    <h3><span class="section-icon">📋</span> Добро пожаловать в CRM Юрист</h3>
                    <p class="text-muted">Выберите раздел в боковом меню, чтобы начать работу.</p>
                </div>
            `;
        } catch (e) {
            document.getElementById('contentArea').innerHTML = `
                <div class="content-card"><div class="empty-state">
                    <span class="empty-icon">⚠️</span><p>Не удалось загрузить дашборд</p>
                </div></div>
            `;
        }
    },

    // ========== CLIENTS ==========
    async loadClients(search = '') {
        try {
            const url = search ? `/api/clients?search=${encodeURIComponent(search)}` : '/api/clients';
            const data = await App.api(url);
            document.getElementById('statsRow').innerHTML = '';
            let html = `
                <div class="content-card">
                    <h3><span class="section-icon">👥</span> Клиенты</h3>
                    <div class="toolbar">
                        <input type="text" id="clientSearch" placeholder="🔍 Поиск по имени или телефону..." value="${App.escHtml(search)}" onkeyup="if(event.key==='Enter')App.loadClients(this.value)">
                        <button class="btn btn-accent" onclick="App.loadClients(document.getElementById('clientSearch').value)">🔍 Найти</button>
                        <button class="btn btn-outline" onclick="App.exportClients()">📥 Excel</button>
                    </div>
                    <div class="table-wrap">
                        <table>
                            <thead><tr><th>ID</th><th>ФИО</th><th>Телефон</th><th>Email</th><th>Статус</th><th>Действия</th></tr></thead>
                            <tbody>`;
            if (data.length === 0) {
                html += `<tr><td colspan="6"><div class="empty-state"><span class="empty-icon">📭</span><p>Клиенты не найдены</p></div></td></tr>`;
            } else {
                data.forEach(c => {
                    const badge = c.status === 'active' ? 'badge-active' : 'badge-closed';
                    html += `
                        <tr>
                            <td><strong>#${c.id}</strong></td>
                            <td><span class="text-link" onclick="App.viewClient(${c.id})">${App.escHtml(c.full_name)}</span></td>
                            <td>${App.escHtml(c.phone || '—')}</td>
                            <td>${App.escHtml(c.email || '—')}</td>
                            <td><span class="badge ${badge}">${c.status === 'active' ? 'Активен' : 'Неактивен'}</span></td>
                            <td class="gap-2">
                                <button class="btn btn-accent btn-sm" onclick="App.editClient(${c.id})">✏️</button>
                                <button class="btn btn-danger btn-sm" onclick="App.deleteClient(${c.id})">🗑</button>
                            </td>
                        </tr>`;
                });
            }
            html += `</tbody></table></div></div>`;
            document.getElementById('contentArea').innerHTML = html;
        } catch (e) {
            document.getElementById('contentArea').innerHTML = `<div class="content-card"><div class="empty-state"><span class="empty-icon">⚠️</span><p>Ошибка загрузки</p></div></div>`;
        }
    },

    async exportClients() {
        try {
            const res = await fetch('/api/clients/export/excel', { credentials: 'include' });
            const blob = await res.blob();
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a'); a.href = url; a.download = 'clients.xlsx'; a.click();
            URL.revokeObjectURL(url);
        } catch (e) { alert('Ошибка экспорта'); }
    },

    showClientForm() {
        App.openModal('➕ Новый клиент', `
            <div class="form-group"><label>ФИО *</label><input id="cfname"></div>
            <div class="form-group"><label>Телефон</label><input id="cphone"></div>
            <div class="form-group"><label>Email</label><input id="cemail"></div>
            <div class="form-group"><label>Теги</label><input id="ctags"></div>
            <div class="form-group"><label>Заметки</label><textarea id="cnotes"></textarea></div>
            <div class="form-actions">
                <button class="btn btn-outline" onclick="App.closeModal()">Отмена</button>
                <button class="btn btn-accent" onclick="App.saveClient()">Сохранить</button>
            </div>
        `);
    },

    async saveClient() {
        const data = {
            full_name: document.getElementById('cfname').value,
            phone: document.getElementById('cphone').value,
            email: document.getElementById('cemail').value,
            tags: document.getElementById('ctags').value,
            notes: document.getElementById('cnotes').value
        };
        if (!data.full_name) { alert('Введите ФИО'); return; }
        try { await App.api('/api/clients', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }); App.closeModal(); App.loadClients(); }
        catch (e) { alert(e.message); }
    },

    async editClient(id) {
        try {
            const c = await App.api(`/api/clients/${id}`);
            App.openModal('✏️ Изменить клиента', `
                <div class="form-group"><label>ФИО</label><input id="cfname" value="${App.escHtml(c.full_name || '')}"></div>
                <div class="form-group"><label>Телефон</label><input id="cphone" value="${App.escHtml(c.phone || '')}"></div>
                <div class="form-group"><label>Email</label><input id="cemail" value="${App.escHtml(c.email || '')}"></div>
                <div class="form-group"><label>Теги</label><input id="ctags" value="${App.escHtml(c.tags || '')}"></div>
                <div class="form-group"><label>Заметки</label><textarea id="cnotes">${App.escHtml(c.notes || '')}</textarea></div>
                <p class="text-muted mt-2">🔗 ${window.location.origin}/client/${c.access_code}</p>
                <div class="form-actions">
                    <button class="btn btn-outline" onclick="App.closeModal()">Отмена</button>
                    <button class="btn btn-accent" onclick="App.updateClient(${id})">Сохранить</button>
                </div>
            `);
        } catch (e) { alert('Ошибка загрузки клиента'); }
    },

    async updateClient(id) {
        const data = {
            full_name: document.getElementById('cfname').value,
            phone: document.getElementById('cphone').value,
            email: document.getElementById('cemail').value,
            tags: document.getElementById('ctags').value,
            notes: document.getElementById('cnotes').value
        };
        try { await App.api(`/api/clients/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }); App.closeModal(); App.loadClients(); }
        catch (e) { alert(e.message); }
    },

    async deleteClient(id) {
        if (!confirm('Удалить клиента и все связанные дела?')) return;
        try { await App.api(`/api/clients/${id}`, { method: 'DELETE' }); App.loadClients(); }
        catch (e) { alert(e.message); }
    },

    async viewClient(id) {
        try {
            const c = await App.api(`/api/clients/${id}`);
            App.openModal(`👤 ${App.escHtml(c.full_name)}`, `
                <p><strong>Телефон:</strong> ${App.escHtml(c.phone || '—')}</p>
                <p><strong>Email:</strong> ${App.escHtml(c.email || '—')}</p>
                <p><strong>Статус:</strong> ${c.status}</p>
                <p><strong>Теги:</strong> ${App.escHtml(c.tags || '—')}</p>
                <p><strong>Заметки:</strong> ${App.escHtml(c.notes || '—')}</p>
                <p class="text-muted mt-2">🔗 ${window.location.origin}/client/${c.access_code}</p>
                <div class="form-actions"><button class="btn btn-outline" onclick="App.closeModal()">Закрыть</button></div>
            `);
        } catch (e) { alert('Ошибка'); }
    },

    // ========== CASES ==========
    async loadCases(search = '') {
        try {
            const url = search ? `/api/cases?search=${encodeURIComponent(search)}` : '/api/cases';
            const data = await App.api(url);
            document.getElementById('statsRow').innerHTML = '';
            let html = `
                <div class="content-card">
                    <h3><span class="section-icon">📁</span> Дела</h3>
                    <div class="toolbar">
                        <input type="text" id="caseSearch" placeholder="🔍 Поиск по названию дела..." value="${App.escHtml(search)}" onkeyup="if(event.key==='Enter')App.loadCases(this.value)">
                        <button class="btn btn-accent" onclick="App.loadCases(document.getElementById('caseSearch').value)">🔍 Найти</button>
                    </div>
                    <div class="table-wrap">
                        <table>
                            <thead><tr><th>ID</th><th>Название</th><th>Тип</th><th>Клиент</th><th>Ответственный</th><th>Статус</th><th>Действия</th></tr></thead>
                            <tbody>`;
            if (data.length === 0) {
                html += `<tr><td colspan="7"><div class="empty-state"><span class="empty-icon">📭</span><p>Дела не найдены</p></div></td></tr>`;
            } else {
                data.forEach(c => {
                    let badgeClass = 'badge-new';
                    let badgeText = 'Новое';
                    if (c.status === 'active') { badgeClass = 'badge-active'; badgeText = 'В работе'; }
                    else if (c.status === 'closed') { badgeClass = 'badge-closed'; badgeText = 'Закрыто'; }
                    html += `
                        <tr>
                            <td><strong>#${c.id}</strong></td>
                            <td><span class="text-link" onclick="App.viewCase(${c.id})">${App.escHtml(c.title)}</span></td>
                            <td>${App.escHtml(c.case_type || '—')}</td>
                            <td>${App.escHtml(c.client_name || '—')}</td>
                            <td>${App.escHtml(c.owner_name || '—')}</td>
                            <td><span class="badge ${badgeClass}">${badgeText}</span></td>
                            <td class="gap-2">
                                <button class="btn btn-accent btn-sm" onclick="App.editCase(${c.id})">✏️</button>
                                <button class="btn btn-danger btn-sm" onclick="App.deleteCase(${c.id})">🗑</button>
                            </td>
                        </tr>`;
                });
            }
            html += `</tbody></table></div></div>`;
            document.getElementById('contentArea').innerHTML = html;
        } catch (e) {
            document.getElementById('contentArea').innerHTML = `<div class="content-card"><div class="empty-state"><span class="empty-icon">⚠️</span><p>Ошибка загрузки</p></div></div>`;
        }
    },

    showCaseForm() {
        App.openModal('➕ Новое дело', `
            <div class="form-group"><label>Клиент ID *</label><input id="cclient" type="number"></div>
            <div class="form-group"><label>Название *</label><input id="ctitle"></div>
            <div class="form-group"><label>Тип дела</label><input id="ctype"></div>
            <div class="form-group"><label>Описание</label><textarea id="cdesc"></textarea></div>
            <div class="form-actions">
                <button class="btn btn-outline" onclick="App.closeModal()">Отмена</button>
                <button class="btn btn-accent" onclick="App.saveCase()">Сохранить</button>
            </div>
        `);
    },

    async saveCase() {
        const data = {
            client_id: parseInt(document.getElementById('cclient').value),
            title: document.getElementById('ctitle').value,
            case_type: document.getElementById('ctype').value,
            description: document.getElementById('cdesc').value
        };
        if (!data.client_id || !data.title) { alert('Заполните обязательные поля'); return; }
        try { await App.api('/api/cases', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }); App.closeModal(); App.loadCases(); }
        catch (e) { alert(e.message); }
    },

    async viewCase(id) {
        try {
            const c = await App.api(`/api/cases/${id}`);
            let docsHtml = (c.documents || []).map(d => `<p>📄 <a href="${d.file_path}" target="_blank" class="text-link">${App.escHtml(d.name)}</a></p>`).join('') || '<p class="text-muted">Нет документов</p>';
            let paysHtml = (c.payments || []).map(p => `<p>💰 ${p.amount} ₽ — ${p.status}</p>`).join('') || '<p class="text-muted">Нет платежей</p>';
            App.openModal(`📁 ${App.escHtml(c.title)}`, `
                <p><strong>Клиент:</strong> ${App.escHtml(c.client?.full_name || '—')}</p>
                <p><strong>Статус:</strong> ${c.status}</p>
                <p><strong>Тип:</strong> ${App.escHtml(c.case_type || '—')}</p>
                <p><strong>Описание:</strong> ${App.escHtml(c.description || '—')}</p>
                <hr style="border-color:var(--border);margin:16px 0;">
                <h4>📄 Документы</h4>${docsHtml}
                <h4 style="margin-top:12px;">💰 Платежи</h4>${paysHtml}
                <div class="form-actions"><button class="btn btn-outline" onclick="App.closeModal()">Закрыть</button></div>
            `);
        } catch (e) { alert('Ошибка загрузки дела'); }
    },

    async editCase(id) {
        try {
            const c = await App.api(`/api/cases/${id}`);
            App.openModal('✏️ Изменить дело', `
                <div class="form-group"><label>Название</label><input id="ctitle" value="${App.escHtml(c.title || '')}"></div>
                <div class="form-group"><label>Тип</label><input id="ctype" value="${App.escHtml(c.case_type || '')}"></div>
                <div class="form-group"><label>Описание</label><textarea id="cdesc">${App.escHtml(c.description || '')}</textarea></div>
                <div class="form-group"><label>Статус</label><select id="cstatus">
                    <option value="new" ${c.status==='new'?'selected':''}>Новое</option>
                    <option value="active" ${c.status==='active'?'selected':''}>В работе</option>
                    <option value="closed" ${c.status==='closed'?'selected':''}>Закрыто</option>
                </select></div>
                <div class="form-actions">
                    <button class="btn btn-outline" onclick="App.closeModal()">Отмена</button>
                    <button class="btn btn-accent" onclick="App.updateCase(${id})">Сохранить</button>
                </div>
            `);
        } catch (e) { alert('Ошибка'); }
    },

    async updateCase(id) {
        const data = {
            title: document.getElementById('ctitle').value,
            case_type: document.getElementById('ctype').value,
            description: document.getElementById('cdesc').value,
            status: document.getElementById('cstatus').value
        };
        try { await App.api(`/api/cases/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }); App.closeModal(); App.loadCases(); }
        catch (e) { alert(e.message); }
    },

    async deleteCase(id) {
        if (!confirm('Удалить дело?')) return;
        try { await App.api(`/api/cases/${id}`, { method: 'DELETE' }); App.loadCases(); }
        catch (e) { alert(e.message); }
    },

    // ========== USERS ==========
    async loadUsers() {
        try {
            const data = await App.api('/api/users');
            document.getElementById('statsRow').innerHTML = '';
            let html = `
                <div class="content-card">
                    <h3><span class="section-icon">👤</span> Сотрудники</h3>
                    <div class="table-wrap"><table>
                        <thead><tr><th>ID</th><th>ФИО</th><th>Логин</th><th>Роль</th></tr></thead><tbody>`;
            data.forEach(u => { html += `<tr><td><strong>#${u.id}</strong></td><td>${App.escHtml(u.full_name)}</td><td>${App.escHtml(u.login)}</td><td><span class="badge badge-active">${u.role}</span></td></tr>`; });
            html += `</tbody></table></div></div>`;
            document.getElementById('contentArea').innerHTML = html;
        } catch (e) {
            document.getElementById('contentArea').innerHTML = `<div class="content-card"><div class="empty-state"><span class="empty-icon">🔒</span><p>Нет доступа</p></div></div>`;
        }
    },

    showUserForm() {
        App.openModal('➕ Новый сотрудник', `
            <div class="form-group"><label>ФИО *</label><input id="ufname"></div>
            <div class="form-group"><label>Логин *</label><input id="ulogin"></div>
            <div class="form-group"><label>Пароль *</label><input id="upass" type="password" minlength="6"></div>
            <div class="form-group"><label>Роль</label><select id="urole"><option value="lawyer">Юрист</option><option value="admin">Админ</option></select></div>
            <div class="form-actions">
                <button class="btn btn-outline" onclick="App.closeModal()">Отмена</button>
                <button class="btn btn-accent" onclick="App.saveUser()">Сохранить</button>
            </div>
        `);
    },

    async saveUser() {
        const data = {
            full_name: document.getElementById('ufname').value,
            login: document.getElementById('ulogin').value,
            password: document.getElementById('upass').value,
            role: document.getElementById('urole').value
        };
        if (!data.full_name || !data.login || !data.password) { alert('Заполните все поля'); return; }
        try { await App.api('/api/users', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }); App.closeModal(); App.loadUsers(); }
        catch (e) { alert(e.message); }
    },

    // ========== FINANCE ==========
    async loadFinance() {
        try {
            const [payments, fstats] = await Promise.all([
                App.api('/api/payments'),
                App.api('/api/finance/stats')
            ]);
            document.getElementById('statsRow').innerHTML = `
                <div class="stat-card success">
                    <span class="stat-icon">💰</span>
                    <div class="stat-value">${(fstats.total_revenue || 0).toLocaleString()} ₽</div>
                    <div class="stat-label">Общая выручка</div>
                </div>
            `;
            let html = `
                <div class="content-card">
                    <h3><span class="section-icon">💰</span> Финансы</h3>
                    <div class="table-wrap"><table>
                        <thead><tr><th>ID</th><th>Дело</th><th>Сумма</th><th>Описание</th><th>Статус</th><th>Действия</th></tr></thead><tbody>`;
            if (payments.length === 0) {
                html += `<tr><td colspan="6"><div class="empty-state"><span class="empty-icon">📭</span><p>Платежей нет</p></div></td></tr>`;
            } else {
                payments.forEach(p => {
                    const badge = p.status === 'paid' ? 'badge-closed' : 'badge-active';
                    const badgeText = p.status === 'paid' ? 'Оплачен' : 'Ожидает';
                    html += `
                        <tr>
                            <td><strong>#${p.id}</strong></td>
                            <td>Дело #${p.case_id}</td>
                            <td><strong>${(p.amount || 0).toLocaleString()} ₽</strong></td>
                            <td>${App.escHtml(p.description || '—')}</td>
                            <td><span class="badge ${badge}">${badgeText}</span></td>
                            <td>
                                <button class="btn btn-success btn-sm" onclick="App.markPaid(${p.id})">✅</button>
                                <button class="btn btn-danger btn-sm" onclick="App.deletePayment(${p.id})">🗑</button>
                            </td>
                        </tr>`;
                });
            }
            html += `</tbody></table></div></div>`;
            document.getElementById('contentArea').innerHTML = html;
        } catch (e) {
            document.getElementById('contentArea').innerHTML = `<div class="content-card"><div class="empty-state"><span class="empty-icon">⚠️</span><p>Ошибка загрузки</p></div></div>`;
        }
    },

    showPaymentForm() {
        App.openModal('➕ Новый платёж', `
            <div class="form-group"><label>Дело ID *</label><input id="pcase" type="number"></div>
            <div class="form-group"><label>Сумма (₽) *</label><input id="pamount" type="number"></div>
            <div class="form-group"><label>Описание</label><input id="pdesc"></div>
            <div class="form-actions">
                <button class="btn btn-outline" onclick="App.closeModal()">Отмена</button>
                <button class="btn btn-accent" onclick="App.savePayment()">Сохранить</button>
            </div>
        `);
    },

    async savePayment() {
        const data = {
            case_id: parseInt(document.getElementById('pcase').value),
            amount: parseInt(document.getElementById('pamount').value),
            description: document.getElementById('pdesc').value
        };
        if (!data.case_id || !data.amount) { alert('Заполните обязательные поля'); return; }
        try { await App.api('/api/payments', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }); App.closeModal(); App.loadFinance(); }
        catch (e) { alert(e.message); }
    },

    async markPaid(id) {
        try { await App.api(`/api/payments/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ status: 'paid' }) }); App.loadFinance(); }
        catch (e) { alert(e.message); }
    },

    async deletePayment(id) {
        if (!confirm('Удалить платёж?')) return;
        try { await App.api(`/api/payments/${id}`, { method: 'DELETE' }); App.loadFinance(); }
        catch (e) { alert(e.message); }
    },

    // ========== MODAL ==========
    openModal(title, bodyHtml) {
        document.getElementById('modalContent').innerHTML = `<h2>${title}</h2>${bodyHtml}`;
        document.getElementById('modal').classList.add('active');
    },
    closeModal() { document.getElementById('modal').classList.remove('active'); },

    // ========== UTILS ==========
    toggleTheme() {
        document.body.classList.toggle('dark');
        localStorage.setItem('crm_theme', document.body.classList.contains('dark') ? 'dark' : 'light');
    },
    escHtml(str) {
        if (!str) return '';
        const div = document.createElement('div');
        div.appendChild(document.createTextNode(str));
        return div.innerHTML;
    }
};

// Init
if (localStorage.getItem('crm_theme') === 'dark') document.body.classList.add('dark');
