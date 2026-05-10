const app = {
    baseUrl: '../api', // Assuming the web app is in public_html/app or similar
    token: localStorage.getItem('auth_token'),
    currentUser: JSON.parse(localStorage.getItem('user') || 'null'),
    activeView: 'login',

    init() {
        this.setupEventListeners();
        if (this.token) {
            this.showView('feed');
            this.fetchProfile();
        } else {
            this.showView('login');
        }
    },

    setupEventListeners() {
        document.getElementById('btn-login').onclick = () => this.login();
        document.getElementById('btn-signup').onclick = () => this.signup();
    },

    async request(path, options = {}) {
        const url = `${this.baseUrl}/${path}`;
        const headers = {
            'Content-Type': 'application/json',
            ...options.headers
        };

        if (this.token) {
            headers['Authorization'] = `Bearer ${this.token}`;
        }

        const res = await fetch(url, {
            ...options,
            headers
        });

        const data = await res.json();
        if (!data.success) throw new Error(data.error || 'Request failed');
        return data.data;
    },

    async login() {
        const email = document.getElementById('login-email').value;
        const password = document.getElementById('login-pass').value;

        try {
            const data = await this.request('auth/login.php', {
                method: 'POST',
                body: JSON.stringify({ email, password })
            });

            this.token = data.token;
            this.currentUser = data.user;
            localStorage.setItem('auth_token', this.token);
            localStorage.setItem('user', JSON.stringify(this.currentUser));
            
            this.showView('feed');
            this.fetchProfile();
        } catch (err) {
            alert(err.message);
        }
    },

    async signup() {
        const name = document.getElementById('signup-name').value;
        const email = document.getElementById('signup-email').value;
        const password = document.getElementById('signup-pass').value;

        try {
            const data = await this.request('auth/register.php', {
                method: 'POST',
                body: JSON.stringify({ name, email, password })
            });

            this.token = data.token;
            this.currentUser = data.user;
            localStorage.setItem('auth_token', this.token);
            localStorage.setItem('user', JSON.stringify(this.currentUser));

            this.showView('feed');
            this.fetchProfile();
        } catch (err) {
            alert(err.message);
        }
    },

    logout() {
        this.token = null;
        this.currentUser = null;
        localStorage.clear();
        this.showView('login');
    },

    showView(viewId) {
        document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
        document.getElementById(`view-${viewId}`).classList.add('active');
        
        // Navigation highlight
        const nav = document.getElementById('main-nav');
        if (['login', 'signup'].includes(viewId)) {
            nav.style.display = 'none';
        } else {
            nav.style.display = 'flex';
            document.querySelectorAll('.nav-item').forEach(item => {
                const text = item.querySelector('span').innerText.toLowerCase().replace(' ', '');
                item.classList.toggle('active', text === viewId || (viewId === 'feed' && text === 'home'));
            });
        }

        this.activeView = viewId;
        if (viewId === 'feed') this.fetchFeed();
        if (viewId === 'mybets') this.fetchMyBets();
        if (viewId === 'notifications') this.fetchNotifications();
        if (viewId === 'profile') this.renderProfile();
        
        window.scrollTo(0,0);
    },

    async fetchFeed() {
        const list = document.getElementById('bets-list');
        list.innerHTML = '<div style="text-align:center; padding: 20px;">Loading live bets...</div>';
        
        try {
            const bets = await this.request('bets/feed.php');
            const me = await this.request('auth/me.php');
            document.getElementById('user-balance').innerText = `${me.walletBalance.toFixed(2)}€`;
            
            list.innerHTML = bets.map(bet => this.renderBetCard(bet)).join('');
        } catch (err) {
            list.innerHTML = `<div style="color:var(--danger); padding:20px;">${err.message}</div>`;
        }
    },

    renderBetCard(bet) {
        const isLocked = new Date(bet.close_at) <= new Date();
        const statusBadge = isLocked ? '<span class="badge badge-locked">Locked</span>' : '<span class="badge badge-live">Live</span>';
        
        return `
            <div class="card ${isLocked ? '' : 'active'} animate-fade" onclick="app.showBetDetail(${bet.id})">
                <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px;">
                    <div>
                        <div style="font-weight: 700; font-size: 16px;">${bet.title}</div>
                        <div class="text-small">by @${bet.creator_name}</div>
                    </div>
                    ${statusBadge}
                </div>
                <div class="odds-grid">
                    ${bet.outcomes.slice(0, 2).map(o => `
                        <div class="outcome-row">
                            <span class="outcome-label">${o.label}</span>
                            <span class="outcome-coeff">${o.coefficient.toFixed(2)}</span>
                        </div>
                    `).join('')}
                </div>
                <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 15px;">
                    <div class="text-small countdown">${this.formatCountdown(bet.close_at)}</div>
                    <div class="text-small" style="font-weight: 800;">
                        <i class="fas fa-ticket-alt"></i> ${bet.wager_count || 0}
                        &nbsp;&nbsp;
                        <i class="fas fa-coins"></i> ${bet.total_wagered || 0}€
                    </div>
                </div>
            </div>
        `;
    },

    async fetchMyBets() {
        const list = document.getElementById('my-bets-list');
        list.innerHTML = '<div style="text-align:center; padding: 20px;">Loading history...</div>';
        
        try {
            const wagers = await this.request('wagers/my_bets.php');
            list.innerHTML = wagers.map(wager => `
                <div class="card animate-fade" style="background-color: var(--background); border-color: var(--primary);">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                        <div style="font-weight: 700;">${wager.title}</div>
                        <span class="badge badge-${wager.status}">${wager.status}</span>
                    </div>
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <div style="font-weight: 700; color: #fff;">${wager.outcomeLabel}</div>
                        <div style="color: var(--primary); font-family: monospace; font-weight: 700;">@ ${wager.lockedCoefficient.toFixed(2)}</div>
                    </div>
                    <div style="height: 1px; background: rgba(255,255,255,0.1); margin: 12px 0;"></div>
                    <div style="display: flex; justify-content: space-between;">
                        <div>
                            <div class="text-small" style="font-weight: 900;">STAKE</div>
                            <div style="font-weight: 700; font-size: 18px;">${wager.stake.toFixed(2)}€</div>
                        </div>
                        <div style="text-align: right;">
                            <div class="text-small" style="font-weight: 900;">${wager.status === 'won' ? 'PAYOUT' : 'POTENTIAL'}</div>
                            <div style="font-weight: 700; font-size: 18px; color: ${wager.status === 'won' ? 'var(--odds-up)' : '#fff'}">${wager.potentialReturn.toFixed(2)}€</div>
                        </div>
                    </div>
                </div>
            `).join('');
        } catch (err) {
            list.innerHTML = `<div style="color:var(--danger); padding:20px;">${err.message}</div>`;
        }
    },

    async fetchNotifications() {
        const list = document.getElementById('notifications-list');
        try {
            const notes = await this.request('notifications/list.php');
            list.innerHTML = notes.map(n => `
                <div class="card animate-fade" style="padding: 12px; margin: 8px 16px; border: none; border-left: 3px solid var(--primary);">
                    <div style="font-size: 14px;">${n.message}</div>
                    <div class="text-small" style="margin-top: 4px;">${n.created_at}</div>
                </div>
            `).join('');
        } catch (err) {
            list.innerHTML = `<div style="color:var(--danger); padding:20px;">${err.message}</div>`;
        }
    },

    renderProfile() {
        if (!this.currentUser) return;
        document.getElementById('profile-name').innerText = this.currentUser.name;
        document.getElementById('profile-email').innerText = this.currentUser.email;
        if (this.currentUser.avatarUrl) {
            document.getElementById('profile-avatar').innerHTML = `<img src="${this.currentUser.avatarUrl}" style="width:100%; height:100%; border-radius:50%; object-fit:cover;">`;
        }
    },

    async fetchProfile() {
        try {
            const data = await this.request('users/profile.php');
            // Update local user data if needed
        } catch (err) {}
    },

    formatCountdown(dateStr) {
        const diff = new Date(dateStr) - new Date();
        if (diff <= 0) return "CLOSED";
        const mins = Math.floor(diff / 60000);
        const secs = Math.floor((diff % 60000) / 1000);
        return `ENDS IN: ${mins}:${secs < 10 ? '0' : ''}${secs}${mins < 10 ? '!' : ''}`;
    },

    async showBetDetail(id) {
        this.showView('bet-detail');
        const content = document.getElementById('detail-content');
        content.innerHTML = '<div style="text-align:center; padding: 40px;">Loading details...</div>';
        
        try {
            const bet = await this.request(`bets/detail.php?id=${id}`);
            document.getElementById('detail-title').innerText = bet.title;
            
            content.innerHTML = `
                <div class="card" style="border: none;">
                    <p style="color: var(--text-secondary);">${bet.description || 'No description provided.'}</p>
                    <div style="display:flex; justify-content: space-between; font-size: 14px;">
                        <span>Total Wagered: <b>${bet.total_wagered}€</b></span>
                        <span>Wagers: <b>${bet.wager_count}</b></span>
                    </div>
                </div>
                <h3 style="padding: 0 16px; margin-top: 20px;">Choose Outcome</h3>
                <div style="padding: 0 16px; display: flex; flex-direction: column; gap: 10px;">
                    ${bet.outcomes.map(o => `
                        <div class="card" style="margin: 0; cursor: pointer; display: flex; justify-content: space-between;" onclick="app.selectOutcome(${o.id}, '${o.label}', ${o.coefficient})">
                            <span style="font-weight: 700;">${o.label}</span>
                            <span style="color: var(--primary); font-weight: 700;">${o.coefficient.toFixed(2)}</span>
                        </div>
                    `).join('')}
                </div>
            `;
        } catch (err) {
            content.innerHTML = `<div style="color:var(--danger); padding:20px;">${err.message}</div>`;
        }
    },

    selectOutcome(id, label, coeff) {
        const stake = prompt(`Place wager on "${label}" @ ${coeff.toFixed(2)}\nEnter amount (€):`, "10");
        if (!stake || isNaN(stake) || stake <= 0) return;
        
        this.placeWager(id, parseFloat(stake));
    },

    async placeWager(outcomeId, stake) {
        try {
            await this.request('wagers/place.php', {
                method: 'POST',
                body: JSON.stringify({ outcome_id: outcomeId, stake })
            });
            alert("Wager placed successfully! 🎰");
            this.showView('mybets');
        } catch (err) {
            alert("Error: " + err.message);
        }
    }
};

app.init();
