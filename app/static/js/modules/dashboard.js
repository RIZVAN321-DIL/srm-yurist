const DashboardModule = {
    async load() {
        document.querySelector('.header h1').textContent = '📊 Дашборд'; document.getElementById('stats').innerHTML = '';
        const stats = await App.api('/api/dashboard/stats');
        document.getElementById('stats').innerHTML = `<div class="stat-card"><div class="value">${stats.total_clients||0}</div><div class="label">Всего клиентов</div></div><div class="stat-card"><div class="value">${stats.total_cases||0}</div><div class="label">Всего дел</div></div><div class="stat-card"><div class="value">${stats.active_cases||0}</div><div class="label">Активных дел</div></div><div class="stat-card"><div class="value">${stats.closed_cases||0}</div><div class="label">Закрытых дел</div></div>`;
    }
};
setInterval(() => { if (App.currentTab === 'dashboard') DashboardModule.load(); }, 60000);
