const App = {
    csrfToken: '',
    user: null,
    currentPage: 'dashboard',
    clientsCache: [],
    templatesCache: [],

    async api(url, options = {}) {
        const headers = { ...options.headers, 'X-CSRF-Token': App.csrfToken };
        const res = await fetch(url, { ...options, headers, credentials: 'include' });
        if (res.status === 401) { App.logout(); throw new Error('Unauthorized'); }
        if (res.status === 423) { alert('Аккаунт заблокирован на 15 минут.'); throw new Error('Locked'); }
        if (!res.ok) {
            const d = await res.json().catch(() => ({}));
            throw new Error(typeof d.detail === 'string' ? d.detail : 'Ошибка сервера');
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
            const res = await fetch('/api/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ login, password }) });
            const data = await res.json();
            if (!data.ok) { errEl.textContent = data.detail || 'Ошибка входа'; return; }
            App.csrfToken = data.csrf_token; App.user = data.user;
            document.getElementById('loginOverlay').style.display = 'none';
            document.getElementById('appLayout').style.display = 'flex';
            if (data.user.force_password_change) { App.showPasswordChange(); }
            else { App.updateSidebar(); App.navigate('dashboard'); }
        } catch (e) { errEl.textContent = 'Ошибка соединения'; }
    },

    async logout() {
        try { await fetch('/api/auth/logout', { method: 'POST', credentials: 'include' }); } catch (e) {}
        App.csrfToken = ''; App.user = null;
        document.getElementById('loginOverlay').style.display = 'flex';
        document.getElementById('appLayout').style.display = 'none';
    },

    showPasswordChange() {
        App.openModal('Смена пароля', `
            <p style="color:var(--danger);margin-bottom:18px;font-weight:600;">Перед началом работы необходимо сменить пароль.</p>
            <div class="form-group"><label>Старый пароль</label><input id="oldpw" type="password" value="admin123"></div>
            <div class="form-group"><label>Новый пароль (мин. 6 символов)</label><input id="newpw" type="password" minlength="6"></div>
            <div class="form-group"><label>Повторите пароль</label><input id="newpw2" type="password" minlength="6"></div>
            <div id="pwError" style="color:var(--danger);font-size:13px;margin-top:8px;"></div>
            <div class="form-actions"><button class="btn btn-accent" onclick="App.changePassword()">Сменить пароль</button></div>
        `);
    },

    async changePassword() {
        const n1 = document.getElementById('newpw').value, n2 = document.getElementById('newpw2').value;
        const errEl = document.getElementById('pwError');
        if (n1.length < 6) { errEl.textContent = 'Минимум 6 символов'; return; }
        if (n1 !== n2) { errEl.textContent = 'Пароли не совпадают'; return; }
        try {
            await App.api('/api/auth/change-password', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ old_password: document.getElementById('oldpw').value, new_password: n1 }) });
            App.closeModal(); App.user.force_password_change = false; App.navigate('dashboard'); alert('Пароль изменён!');
        } catch (e) { errEl.textContent = App.err(e); }
    },

    // ========== NAVIGATION ==========
    updateSidebar() {
        document.querySelectorAll('.sidebar a[data-nav]').forEach(a => { a.classList.remove('active'); if (a.dataset.nav === App.currentPage) a.classList.add('active'); });
        document.getElementById('globalAddBtn').style.display = ['clients','cases','users','finance'].includes(App.currentPage) ? 'inline-flex' : 'none';
        document.getElementById('pageTitle').textContent = { dashboard:'Дашборд', clients:'Клиенты', cases:'Дела', users:'Сотрудники', finance:'Финансы' }[App.currentPage] || 'CRM';
        document.getElementById('pageDate').textContent = new Date().toLocaleDateString('ru-RU', { weekday:'long', year:'numeric', month:'long', day:'numeric' });
    },

    navigate(page) {
        App.currentPage = page; App.updateSidebar();
        document.getElementById('statsRow').innerHTML = '';
        document.getElementById('contentArea').innerHTML = '<div class="content-card"><p style="text-align:center;padding:20px;">Загрузка...</p></div>';
        ({ dashboard: App.loadDashboard, clients: App.loadClients, cases: App.loadCases, users: App.loadUsers, finance: App.loadFinance }[page] || App.loadDashboard)();
    },

    handleGlobalAdd() {
        ({ clients: App.showClientForm, cases: App.showCaseForm, users: App.showUserForm, finance: App.showPaymentForm }[App.currentPage] || (() => {}))();
    },

    // ========== DASHBOARD ==========
    async loadDashboard() {
        try {
            const s = await App.api('/api/dashboard/stats');
            document.getElementById('statsRow').innerHTML = `
                <div class="stat-card accent"><span class="stat-icon">👥</span><div class="stat-value">${s.total_clients||0}</div><div class="stat-label">Клиентов</div></div>
                <div class="stat-card info"><span class="stat-icon">📁</span><div class="stat-value">${s.total_cases||0}</div><div class="stat-label">Дел</div></div>
                <div class="stat-card warning"><span class="stat-icon">⚡</span><div class="stat-value">${s.active_cases||0}</div><div class="stat-label">В работе</div></div>
                <div class="stat-card success"><span class="stat-icon">✅</span><div class="stat-value">${s.closed_cases||0}</div><div class="stat-label">Закрыто</div></div>`;
            document.getElementById('contentArea').innerHTML = `<div class="content-card"><h3>ГрадПроект CRM</h3><p class="text-muted">Ипотека • Маткапитал • Соцконтракт • Оформление недвижимости</p></div>`;
        } catch (e) {}
    },

    // ========== CLIENTS ==========
    async loadClients(search = '') {
        try {
            const url = search ? `/api/clients?search=${encodeURIComponent(search)}` : '/api/clients';
            const data = await App.api(url); App.clientsCache = data;
            document.getElementById('statsRow').innerHTML = '';
            let h = `<div class="content-card"><h3>Клиенты (${data.length})</h3>
                <div class="toolbar"><input type="text" id="clientSearch" placeholder="Поиск..." value="${App.esc(search)}" onkeyup="if(event.key==='Enter')App.loadClients(this.value)">
                <button class="btn btn-accent" onclick="App.loadClients(document.getElementById('clientSearch').value)">🔍</button>
                <button class="btn btn-outline" onclick="App.exportClients()">📥 Excel</button></div>
                <div class="table-wrap"><table><thead><tr><th>ID</th><th>ФИО</th><th>Телефон</th><th>Email</th><th>Статус</th><th>Дел</th><th></th></tr></thead><tbody>`;
            if (!data.length) h += `<tr><td colspan="7"><div class="empty-state"><p>Нет клиентов</p></div></td></tr>`;
            else for (const c of data) {
                let cc = '—'; try { const cs = await App.api(`/api/cases?client_id=${c.id}`); cc = cs.length; } catch (e) {}
                h += `<tr><td><strong>#${c.id}</strong></td><td><span class="text-link" onclick="App.viewClient(${c.id})">${App.esc(c.full_name)}</span></td>
                    <td>${App.esc(c.phone||'—')}</td><td>${App.esc(c.email||'—')}</td>
                    <td><span class="badge ${c.status==='active'?'badge-active':'badge-closed'}">${c.status==='active'?'Активен':'Неактивен'}</span></td>
                    <td><strong>${cc}</strong></td>
                    <td style="display:flex;gap:4px;"><button class="btn btn-accent btn-sm" onclick="App.quickAddCase(${c.id})">+📁</button>
                    <button class="btn btn-accent btn-sm" onclick="App.editClient(${c.id})">✏️</button>
                    <button class="btn btn-outline btn-sm" onclick="App.copyLink('${c.access_code}')">🔗</button>
                    <button class="btn btn-danger btn-sm" onclick="App.deleteClient(${c.id})">🗑</button></td></tr>`;
            }
            h += `</tbody></table></div></div>`;
            document.getElementById('contentArea').innerHTML = h;
        } catch (e) {}
    },

    async exportClients() {
        try {
            const res = await fetch('/api/clients/export/excel', { credentials: 'include' });
            const blob = await res.blob(); const url = URL.createObjectURL(blob);
            const a = document.createElement('a'); a.href = url; a.download = 'clients.xlsx'; a.click(); URL.revokeObjectURL(url);
        } catch (e) { alert('Ошибка экспорта'); }
    },

    copyLink(code) {
        const link = `${window.location.origin}/client/${code}`;
        navigator.clipboard.writeText(link).then(() => alert('Ссылка скопирована!')).catch(() => prompt('Ссылка:', link));
    },

    showClientForm() {
        App.openModal('Новый клиент', `
            <div class="form-group"><label>ФИО *</label><input id="cfname" placeholder="Иванов Иван Иванович"></div>
            <div class="form-group"><label>Телефон</label><input id="cphone" type="tel" placeholder="+7 999 123-45-67"></div>
            <div class="form-group"><label>Email</label><input id="cemail" type="email" placeholder="client@mail.ru"></div>
            <div class="form-group"><label>Теги</label><input id="ctags" placeholder="ипотека, маткапитал"></div>
            <div class="form-group"><label>Заметки</label><textarea id="cnotes" placeholder="Информация..."></textarea></div>
            <div id="fErr" style="color:var(--danger);font-size:13px;margin-top:4px;"></div>
            <div class="form-actions"><button class="btn btn-outline" onclick="App.closeModal()">Отмена</button><button class="btn btn-accent" onclick="App.saveClient()">Сохранить</button></div>`);
    },

    async saveClient() {
        const n = document.getElementById('cfname').value.trim();
        if (!n) { const e = document.getElementById('fErr'); if (e) e.textContent = 'Введите ФИО'; return; }
        try {
            await App.api('/api/clients', { method: 'POST', headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ full_name: n, phone: document.getElementById('cphone').value.trim(), email: document.getElementById('cemail').value.trim(), tags: document.getElementById('ctags').value.trim(), notes: document.getElementById('cnotes').value.trim() }) });
            App.closeModal(); App.loadClients();
        } catch (e) { const el = document.getElementById('fErr'); if (el) el.textContent = App.err(e); }
    },

    async editClient(id) {
        const c = await App.api(`/api/clients/${id}`);
        App.openModal('Изменить клиента', `
            <div class="form-group"><label>ФИО</label><input id="cfname" value="${App.esc(c.full_name||'')}"></div>
            <div class="form-group"><label>Телефон</label><input id="cphone" value="${App.esc(c.phone||'')}"></div>
            <div class="form-group"><label>Email</label><input id="cemail" value="${App.esc(c.email||'')}"></div>
            <div class="form-group"><label>Теги</label><input id="ctags" value="${App.esc(c.tags||'')}"></div>
            <div class="form-group"><label>Заметки</label><textarea id="cnotes">${App.esc(c.notes||'')}</textarea></div>
            <p class="text-muted mt-2">Ссылка: ${window.location.origin}/client/${c.access_code} <button class="btn btn-outline btn-sm" onclick="App.copyLink('${c.access_code}')">📋</button></p>
            <div class="form-actions"><button class="btn btn-outline" onclick="App.closeModal()">Отмена</button><button class="btn btn-accent" onclick="App.updateClient(${id})">Сохранить</button></div>`);
    },

    async updateClient(id) {
        await App.api(`/api/clients/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ full_name: document.getElementById('cfname').value.trim(), phone: document.getElementById('cphone').value.trim(), email: document.getElementById('cemail').value.trim(), tags: document.getElementById('ctags').value.trim(), notes: document.getElementById('cnotes').value.trim() }) });
        App.closeModal(); App.loadClients();
    },

    async deleteClient(id) {
        if (!confirm('Удалить клиента и все его дела?')) return;
        await App.api(`/api/clients/${id}`, { method: 'DELETE' }); App.loadClients();
    },

    async viewClient(id) {
        const c = await App.api(`/api/clients/${id}`);
        let casesHtml = '<p class="text-muted">Загрузка...</p>';
        try {
            const cases = await App.api(`/api/cases?client_id=${id}`);
            casesHtml = cases.length ? cases.map(cs => `<p>📁 <span class="text-link" onclick="App.closeModal();App.navigate('cases');setTimeout(()=>App.viewCase(${cs.id}),300)">${App.esc(cs.title)}</span> <span class="badge badge-${cs.status==='closed'?'closed':cs.status==='active'?'active':'new'}">${cs.status==='closed'?'Закрыто':cs.status==='active'?'В работе':'Новое'}</span></p>`).join('') : '<p class="text-muted">Дел нет</p>';
        } catch (e) {}
        App.openModal(`${App.esc(c.full_name)}`, `
            <p>📞 ${App.esc(c.phone||'—')} | 📧 ${App.esc(c.email||'—')}</p>
            <p>📌 ${c.status==='active'?'Активен':'Неактивен'} | 🏷 ${App.esc(c.tags||'—')}</p>
            <p>📝 ${App.esc(c.notes||'—')}</p>
            <p class="text-muted mt-2">🔗 <a href="${window.location.origin}/client/${c.access_code}" target="_blank" class="text-link">Портал клиента</a></p>
            <hr style="border-color:var(--border);margin:16px 0;"><h4>📁 Дела</h4>${casesHtml}
            <div class="form-actions"><button class="btn btn-accent btn-sm" onclick="App.closeModal();App.quickAddCase(${c.id})">+ Дело</button><button class="btn btn-outline" onclick="App.closeModal()">Закрыть</button></div>`);
    },

    // ========== QUICK CASE ==========
    async quickAddCase(clientId) {
        await App.loadTemplates();
        const opts = App.templatesCache.map(t => `<option value="${t.id}">${t.name}</option>`).join('');
        App.openModal('Новое дело', `
            <p class="text-muted mb-4">Клиент: <strong>#${clientId}</strong></p>
            <div class="form-group"><label>Тип дела *</label><select id="qtemplate">${opts}</select></div>
            <div class="form-group"><label>Название *</label><input id="qtitle" placeholder="Название дела"></div>
            <div class="form-group"><label>Описание</label><textarea id="qdesc" placeholder="Подробности..."></textarea></div>
            <div class="form-actions"><button class="btn btn-outline" onclick="App.closeModal()">Отмена</button><button class="btn btn-accent" onclick="App.saveQuickCase(${clientId})">Сохранить</button></div>`);
    },

    async saveQuickCase(clientId) {
        const title = document.getElementById('qtitle').value.trim(), template_id = parseInt(document.getElementById('qtemplate').value);
        if (!title || !template_id) { alert('Заполните обязательные поля'); return; }
        await App.api('/api/cases', { method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ client_id: clientId, title, template_id, description: document.getElementById('qdesc').value.trim() }) });
        App.closeModal(); App.currentPage === 'clients' ? App.loadClients() : App.loadCases();
    },

    async loadTemplates() { if (!App.templatesCache.length) try { App.templatesCache = await App.api('/api/templates'); } catch (e) {} },

    // ========== CASES ==========
    async loadCases(search = '') {
        try {
            const url = search ? `/api/cases?search=${encodeURIComponent(search)}` : '/api/cases';
            const data = await App.api(url);
            document.getElementById('statsRow').innerHTML = '';
            let h = `<div class="content-card"><h3>Дела (${data.length})</h3>
                <div class="toolbar"><input type="text" id="caseSearch" placeholder="Поиск..." value="${App.esc(search)}" onkeyup="if(event.key==='Enter')App.loadCases(this.value)">
                <button class="btn btn-accent" onclick="App.loadCases(document.getElementById('caseSearch').value)">🔍</button></div>
                <div class="table-wrap"><table><thead><tr><th>ID</th><th>Название</th><th>Тип</th><th>Клиент</th><th>Статус</th><th></th></tr></thead><tbody>`;
            if (!data.length) h += `<tr><td colspan="6"><div class="empty-state"><p>Дел нет</p></div></td></tr>`;
            else data.forEach(c => {
                const bc = c.status==='closed'?'badge-closed':c.status==='active'?'badge-active':'badge-new';
                const bt = c.status==='closed'?'Закрыто':c.status==='active'?'В работе':'Новое';
                h += `<tr><td><strong>#${c.id}</strong></td><td><span class="text-link" onclick="App.viewCase(${c.id})">${App.esc(c.title)}</span></td>
                    <td>${App.esc(c.case_type||'—')}</td><td>${App.esc(c.client_name||'—')}</td><td><span class="badge ${bc}">${bt}</span></td>
                    <td style="display:flex;gap:4px;"><button class="btn btn-accent btn-sm" onclick="App.editCase(${c.id})">✏️</button>
                    <button class="btn btn-success btn-sm" onclick="App.quickAddPayment(${c.id})">+💰</button>
                    <button class="btn btn-danger btn-sm" onclick="App.deleteCase(${c.id})">🗑</button></td></tr>`;
            });
            h += `</tbody></table></div></div>`;
            document.getElementById('contentArea').innerHTML = h;
        } catch (e) {}
    },

    async showCaseForm() {
        await App.loadTemplates();
        const co = await App.loadClientsForSelect();
        const to = App.templatesCache.map(t => `<option value="${t.id}">${t.name}</option>`).join('');
        App.openModal('Новое дело', `
            <div class="form-group"><label>Клиент *</label><select id="cclient">${co}</select></div>
            <div class="form-group"><label>Тип дела *</label><select id="ctemplate">${to}</select></div>
            <div class="form-group"><label>Название *</label><input id="ctitle" placeholder="Название дела"></div>
            <div class="form-group"><label>Описание</label><textarea id="cdesc" placeholder="Подробности..."></textarea></div>
            <div class="form-actions"><button class="btn btn-outline" onclick="App.closeModal()">Отмена</button><button class="btn btn-accent" onclick="App.saveCase()">Сохранить</button></div>`);
    },

    async loadClientsForSelect() {
        try { const d = await App.api('/api/clients'); return d.length ? d.map(c => `<option value="${c.id}">${App.esc(c.full_name)}</option>`).join('') : '<option value="">Нет клиентов</option>'; }
        catch (e) { return '<option value="">Ошибка</option>'; }
    },

    async saveCase() {
        const client_id = parseInt(document.getElementById('cclient').value), template_id = parseInt(document.getElementById('ctemplate').value), title = document.getElementById('ctitle').value.trim();
        if (!client_id || !title || !template_id) { alert('Заполните обязательные поля'); return; }
        await App.api('/api/cases', { method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ client_id, title, template_id, description: document.getElementById('cdesc').value.trim() }) });
        App.closeModal(); App.loadCases();
    },

    async viewCase(id) {
        const c = await App.api(`/api/cases/${id}`);
        const stagesHtml = (c.stages||[]).sort((a,b)=>a.order-b.order).map(s => {
            const icon = s.is_completed ? '✅' : '⬜';
            const dl = s.deadline ? new Date(s.deadline).toLocaleDateString('ru-RU') : '—';
            const overdue = !s.is_completed && s.deadline && new Date(s.deadline) < new Date() ? '<span class="badge badge-overdue">ПРОСРОЧЕНО</span>' : '';
            return `<p>${icon} <strong>${App.esc(s.name)}</strong> <span style="font-size:11px;color:var(--text-secondary);">📅 ${dl}</span> ${overdue}</p>`;
        }).join('') || '<p class="text-muted">Нет этапов</p>';
        const docsHtml = (c.documents||[]).map(d => `<p>📄 <a href="/api/documents/${d.id}/download" target="_blank" class="text-link">${App.esc(d.name)}</a> <span style="font-size:10px;color:var(--text-secondary);">${d.is_encrypted ? '🔒' : ''}</span></p>`).join('') || '<p class="text-muted">Нет документов</p>';
        const paysHtml = (c.payments||[]).map(p => `<p>💰 ${(p.amount||0).toLocaleString()} ₽ — ${p.status==='paid'?'✅ Оплачен':'⏳ Ожидает'}</p>`).join('') || '<p class="text-muted">Нет платежей</p>';
        App.openModal(`📁 ${App.esc(c.title)}`, `
            <p><strong>Клиент:</strong> ${App.esc(c.client?.full_name||'—')} | <strong>Статус:</strong> ${c.status==='new'?'🆕 Новое':c.status==='active'?'🟡 В работе':'✅ Закрыто'}</p>
            <p><strong>Тип:</strong> ${App.esc(c.case_type||'—')}</p>
            <hr style="border-color:var(--border);margin:16px 0;"><h4>📋 Этапы</h4>${stagesHtml}
            <h4 style="margin-top:12px;">📄 Документы</h4>${docsHtml}
            <div class="form-actions" style="margin-top:8px;"><button class="btn btn-accent btn-sm" onclick="App.showUpload(${c.id})">📎 Загрузить</button></div>
            <h4 style="margin-top:12px;">💰 Платежи</h4>${paysHtml}
            <div class="form-actions"><button class="btn btn-accent btn-sm" onclick="App.closeModal();App.editCase(${c.id})">✏️</button><button class="btn btn-success btn-sm" onclick="App.closeModal();App.quickAddPayment(${c.id})">+💰</button><button class="btn btn-outline" onclick="App.closeModal()">Закрыть</button></div>`);
    },

    // ========== DOCUMENTS UPLOAD ==========
    showUpload(caseId) {
        App.openModal('📎 Загрузить документ', `
            <p class="text-muted mb-4">Дело: <strong>#${caseId}</strong></p>
            <div class="form-group"><label>Файл *</label><input type="file" id="docFile" accept=".pdf,.jpg,.jpeg,.png,.webp,.gif"></div>
            <div class="form-group"><label>Название документа</label><input id="docName" placeholder="Скан паспорта, договор..."></div>
            <div id="uploadStatus" style="font-size:13px;margin-top:8px;"></div>
            <div class="form-actions"><button class="btn btn-outline" onclick="App.closeModal()">Отмена</button><button class="btn btn-accent" onclick="App.uploadDoc(${caseId})">Загрузить</button></div>`);
    },

    async uploadDoc(caseId) {
        const fileInput = document.getElementById('docFile');
        const file = fileInput.files[0];
        const statusEl = document.getElementById('uploadStatus');
        if (!file) { statusEl.innerHTML = '<span style="color:var(--danger);">Выберите файл</span>'; return; }
        if (file.size > 20 * 1024 * 1024) { statusEl.innerHTML = '<span style="color:var(--danger);">Файл больше 20 МБ</span>'; return; }
        statusEl.innerHTML = 'Загрузка...';
        const formData = new FormData();
        formData.append('case_id', caseId);
        formData.append('file', file, document.getElementById('docName').value || file.name);
        try {
            const res = await fetch('/api/documents/upload', { method: 'POST', headers: { 'X-CSRF-Token': App.csrfToken }, body: formData, credentials: 'include' });
            if (!res.ok) { const d = await res.json().catch(()=>({})); throw new Error(d.detail || 'Ошибка загрузки'); }
            const data = await res.json();
            statusEl.innerHTML = '<span style="color:var(--success);">✅ Загружено!</span>';
            setTimeout(() => { App.closeModal(); App.viewCase(caseId); }, 800);
        } catch (e) { statusEl.innerHTML = `<span style="color:var(--danger);">${App.err(e)}</span>`; }
    },

    async editCase(id) {
        const c = await App.api(`/api/cases/${id}`);
        App.openModal('Изменить дело', `
            <div class="form-group"><label>Название</label><input id="ctitle" value="${App.esc(c.title||'')}"></div>
            <div class="form-group"><label>Описание</label><textarea id="cdesc">${App.esc(c.description||'')}</textarea></div>
            <div class="form-group"><label>Статус</label><select id="cstatus">
                <option value="new" ${c.status==='new'?'selected':''}>🆕 Новое</option>
                <option value="active" ${c.status==='active'?'selected':''}>🟡 В работе</option>
                <option value="closed" ${c.status==='closed'?'selected':''}>✅ Закрыто</option></select></div>
            <div class="form-actions"><button class="btn btn-outline" onclick="App.closeModal()">Отмена</button><button class="btn btn-accent" onclick="App.updateCase(${id})">Сохранить</button></div>`);
    },

    async updateCase(id) {
        await App.api(`/api/cases/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ title: document.getElementById('ctitle').value.trim(), description: document.getElementById('cdesc').value.trim(), status: document.getElementById('cstatus').value }) });
        App.closeModal(); App.loadCases();
    },

    async deleteCase(id) { if (confirm('Удалить дело?')) { await App.api(`/api/cases/${id}`, { method: 'DELETE' }); App.loadCases(); } },

    // ========== PAYMENTS ==========
    async quickAddPayment(caseId) {
        App.openModal('Платёж', `
            <p class="text-muted mb-4">Дело: <strong>#${caseId}</strong></p>
            <div class="form-group"><label>Сумма (₽) *</label><input id="pamount" type="number" placeholder="50000"></div>
            <div class="form-group"><label>Описание</label><input id="pdesc" placeholder="Аванс / Техплан / Регистрация"></div>
            <div class="form-actions"><button class="btn btn-outline" onclick="App.closeModal()">Отмена</button><button class="btn btn-accent" onclick="App.saveQuickPayment(${caseId})">Сохранить</button></div>`);
    },

    async saveQuickPayment(caseId) {
        const amount = parseInt(document.getElementById('pamount').value);
        if (!amount) { alert('Введите сумму'); return; }
        await App.api('/api/payments', { method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ case_id: caseId, amount, description: document.getElementById('pdesc').value.trim() }) });
        App.closeModal(); App.currentPage === 'finance' ? App.loadFinance() : App.loadCases();
    },

    // ========== USERS ==========
    async loadUsers() {
        const data = await App.api('/api/users');
        document.getElementById('statsRow').innerHTML = '';
        let h = `<div class="content-card"><h3>Сотрудники</h3><div class="table-wrap"><table><thead><tr><th>ID</th><th>ФИО</th><th>Логин</th><th>Роль</th></tr></thead><tbody>`;
        data.forEach(u => h += `<tr><td><strong>#${u.id}</strong></td><td>${App.esc(u.full_name)}</td><td>${App.esc(u.login)}</td><td><span class="badge badge-active">${u.role}</span></td></tr>`);
        h += `</tbody></table></div></div>`;
        document.getElementById('contentArea').innerHTML = h;
    },

    showUserForm() {
        App.openModal('Сотрудник', `
            <div class="form-group"><label>ФИО *</label><input id="ufname"></div>
            <div class="form-group"><label>Логин *</label><input id="ulogin"></div>
            <div class="form-group"><label>Пароль *</label><input id="upass" type="password" minlength="6"></div>
            <div class="form-group"><label>Роль</label><select id="urole"><option value="lawyer">Юрист</option><option value="admin">Админ</option></select></div>
            <div class="form-actions"><button class="btn btn-outline" onclick="App.closeModal()">Отмена</button><button class="btn btn-accent" onclick="App.saveUser()">Сохранить</button></div>`);
    },

    async saveUser() {
        const d = { full_name: document.getElementById('ufname').value.trim(), login: document.getElementById('ulogin').value.trim(), password: document.getElementById('upass').value, role: document.getElementById('urole').value };
        if (!d.full_name || !d.login || !d.password) { alert('Заполните все поля'); return; }
        await App.api('/api/users', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d) });
        App.closeModal(); App.loadUsers();
    },

    // ========== FINANCE ==========
    async loadFinance() {
        const [payments, fstats] = await Promise.all([App.api('/api/payments'), App.api('/api/finance/stats')]);
        document.getElementById('statsRow').innerHTML = `<div class="stat-card success"><span class="stat-icon">💰</span><div class="stat-value">${(fstats.total_revenue||0).toLocaleString()} ₽</div><div class="stat-label">Выручка</div></div>`;
        let h = `<div class="content-card"><h3>Финансы</h3><div class="table-wrap"><table><thead><tr><th>ID</th><th>Дело</th><th>Сумма</th><th>Описание</th><th>Статус</th><th></th></tr></thead><tbody>`;
        payments.forEach(p => h += `<tr><td><strong>#${p.id}</strong></td><td>Дело #${p.case_id}</td><td><strong>${(p.amount||0).toLocaleString()} ₽</strong></td><td>${App.esc(p.description||'—')}</td><td><span class="badge ${p.status==='paid'?'badge-closed':'badge-active'}">${p.status==='paid'?'Оплачен':'Ожидает'}</span></td><td style="display:flex;gap:4px;"><button class="btn btn-success btn-sm" onclick="App.markPaid(${p.id})">✅</button><button class="btn btn-danger btn-sm" onclick="App.deletePayment(${p.id})">🗑</button></td></tr>`);
        h += `</tbody></table></div></div>`;
        document.getElementById('contentArea').innerHTML = h;
    },

    showPaymentForm() {
        App.openModal('Платёж', `
            <div class="form-group"><label>ID дела *</label><input id="pcase" type="number"></div>
            <div class="form-group"><label>Сумма (₽) *</label><input id="pamount" type="number"></div>
            <div class="form-group"><label>Описание</label><input id="pdesc"></div>
            <div class="form-actions"><button class="btn btn-outline" onclick="App.closeModal()">Отмена</button><button class="btn btn-accent" onclick="App.savePayment()">Сохранить</button></div>`);
    },

    async savePayment() {
        const case_id = parseInt(document.getElementById('pcase').value), amount = parseInt(document.getElementById('pamount').value);
        if (!case_id || !amount) { alert('Заполните поля'); return; }
        await App.api('/api/payments', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ case_id, amount, description: document.getElementById('pdesc').value.trim() }) });
        App.closeModal(); App.loadFinance();
    },

    async markPaid(id) { await App.api(`/api/payments/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ status: 'paid' }) }); App.loadFinance(); },
    async deletePayment(id) { if (confirm('Удалить платёж?')) { await App.api(`/api/payments/${id}`, { method: 'DELETE' }); App.loadFinance(); } },

    // ========== MODAL ==========
    openModal(title, body) { document.getElementById('modalContent').innerHTML = `<h2>${title}</h2>${body}`; document.getElementById('modal').classList.add('active'); },
    closeModal() { document.getElementById('modal').classList.remove('active'); },

    // ========== UTILS ==========
    toggleTheme() { document.body.classList.toggle('dark'); localStorage.setItem('crm_theme', document.body.classList.contains('dark')?'dark':'light'); },
    esc(str) { if(!str) return ''; const d = document.createElement('div'); d.appendChild(document.createTextNode(str)); return d.innerHTML; },
    err(e) { if(!e) return 'Ошибка'; const m = e.message||e.toString(); return m==='[object Object]'?'Ошибка сервера':m; }
};
if (localStorage.getItem('crm_theme')==='dark') document.body.classList.add('dark');
