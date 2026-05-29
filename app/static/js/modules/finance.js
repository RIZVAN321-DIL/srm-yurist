const financeModule = {
    paymentsCache: [],
    async load() {
        document.querySelector('.header h1').textContent = '💰 Финансы'; document.getElementById('stats').innerHTML = '';
        try {
            const [payments, stats] = await Promise.all([App.api('/api/payments'), App.api('/api/finance/stats')]);
            financeModule.paymentsCache = payments;
            document.getElementById('stats').innerHTML = `<div class="stat-card"><div class="value">${stats.total_revenue||0}₽</div><div class="label">Общая выручка</div></div>`;
            let html = '<button class="btn btn-success" onclick="financeModule.showForm()" style="margin-bottom:16px">➕ Добавить платёж</button><table><tr><th>ID</th><th>Дело ID</th><th>Сумма</th><th>Статус</th><th>Описание</th><th></th></tr>';
            payments.forEach(p => { html += `<tr><td>${p.id}</td><td>${p.case_id}</td><td>${p.amount}₽</td><td><span class="badge badge-${p.status==='paid'?'active':p.status==='pending'?'new':'closed'}">${p.status}</span></td><td>${App.text(p.description||'—')}</td><td><button class="btn btn-primary" onclick="financeModule.edit(${p.id})">✏️</button> <button class="btn btn-danger" onclick="financeModule.del(${p.id})">🗑️</button></td></tr>`; });
            html += '</table>'; document.getElementById('table-container').innerHTML = html;
        } catch (e) { document.getElementById('table-container').innerHTML = '<p style="color:var(--danger)">Ошибка загрузки финансов.</p>'; }
    },
    showForm() { document.getElementById('modal').classList.add('active'); document.getElementById('modal-content').innerHTML = `<h2>Добавить платёж</h2><div class="form-group"><label>Дело ID</label><input id="pcase" type="number"></div><div class="form-group"><label>Сумма</label><input id="pamount" type="number"></div><div class="form-group"><label>Описание</label><input id="pdesc"></div><div class="form-actions"><button class="btn btn-primary" onclick="financeModule.save()">Сохранить</button><button class="btn btn-danger" onclick="App.closeModal()">Отмена</button></div>`; },
    async save() { const data={case_id:parseInt(document.getElementById('pcase').value),amount:parseInt(document.getElementById('pamount').value),description:document.getElementById('pdesc').value}; await App.api('/api/payments',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}); App.closeModal(); financeModule.load(); },
    edit(id) { const p=financeModule.paymentsCache.find(x=>x.id===id); if(!p) return; document.getElementById('modal').classList.add('active'); document.getElementById('modal-content').innerHTML = `<h2>Изменить платёж</h2><div class="form-group"><label>Сумма</label><input id="pamount" type="number" value="${p.amount}"></div><div class="form-group"><label>Описание</label><input id="pdesc" value="${p.description||''}"></div><div class="form-group"><label>Статус</label><select id="pstatus"><option value="pending" ${p.status==='pending'?'selected':''}>Ожидает</option><option value="paid" ${p.status==='paid'?'selected':''}>Оплачено</option></select></div><div class="form-actions"><button class="btn btn-primary" onclick="financeModule.update(${id})">Сохранить</button><button class="btn btn-danger" onclick="App.closeModal()">Отмена</button></div>`; },
    async update(id) { const data={amount:parseInt(document.getElementById('pamount').value),description:document.getElementById('pdesc').value,status:document.getElementById('pstatus').value}; await App.api('/api/payments/'+id,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}); App.closeModal(); financeModule.load(); },
    async del(id) { if(confirm('Удалить платёж?')){await App.api('/api/payments/'+id,{method:'DELETE'}); financeModule.load();} }
};
