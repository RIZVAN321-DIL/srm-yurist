const usersModule = {
    async load() {
        document.querySelector('.header h1').textContent = '👨‍💼 Сотрудники'; document.getElementById('stats').innerHTML = '';
        try {
            const data = await App.api('/api/users');
            let html = '<button class="btn btn-success" onclick="usersModule.showForm()" style="margin-bottom:16px">➕ Добавить</button><table><tr><th>ID</th><th>ФИО</th><th>Логин</th><th>Роль</th></tr>';
            data.forEach(u => { html += `<tr><td>${u.id}</td><td>${App.text(u.full_name)}</td><td>${App.text(u.login)}</td><td>${App.text(u.role)}</td></tr>`; });
            html += '</table>'; document.getElementById('table-container').innerHTML = html;
        } catch (e) { document.getElementById('table-container').innerHTML = '<p style="color:var(--danger)">Нет доступа к списку сотрудников.</p>'; }
    },
    showForm() { document.getElementById('modal').classList.add('active'); document.getElementById('modal-content').innerHTML = `<h2>Добавить сотрудника</h2><div class="form-group"><label>ФИО</label><input id="ufname"></div><div class="form-group"><label>Логин</label><input id="ulogin"></div><div class="form-group"><label>Пароль (мин. 6 символов)</label><input id="upass" type="password" minlength="6"></div><div class="form-group"><label>Роль</label><select id="urole"><option value="lawyer">Юрист</option><option value="admin">Админ</option><option value="secretary">Секретарь</option></select></div><div class="form-actions"><button class="btn btn-primary" onclick="usersModule.save()">Сохранить</button><button class="btn btn-danger" onclick="App.closeModal()">Отмена</button></div>`; },
    async save() { const data={full_name:document.getElementById('ufname').value,login:document.getElementById('ulogin').value,password:document.getElementById('upass').value,role:document.getElementById('urole').value}; await App.api('/api/users',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}); App.closeModal(); usersModule.load(); }
};
