-- Social Betting App Database Schema

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('player', 'moderator', 'admin') DEFAULT 'player',
    status ENUM('active', 'suspended', 'banned') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    avatar_url VARCHAR(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Social Features: Following system
CREATE TABLE IF NOT EXISTS follows (
    id INT AUTO_INCREMENT PRIMARY KEY,
    follower_id INT NOT NULL,
    followed_id INT NOT NULL,
    status ENUM('pending', 'accepted') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY (follower_id, followed_id),
    FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (followed_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Internal Notifications
CREATE TABLE IF NOT EXISTS notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'bet_approved', 'follow_request', 'new_bet'
    message TEXT NOT NULL,
    related_id INT DEFAULT NULL, -- bet_id or user_id
    is_read TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token_hash VARCHAR(64) NOT NULL,
    device_name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS friendships (
    id INT AUTO_INCREMENT PRIMARY KEY,
    requester_id INT NOT NULL,
    addressee_id INT NOT NULL,
    status ENUM('pending', 'accepted', 'blocked', 'declined') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (addressee_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY (requester_id, addressee_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS wallets (
    user_id INT PRIMARY KEY,
    balance DECIMAL(15, 2) NOT NULL DEFAULT 100.00,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS wallet_ledger (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    entry_type ENUM('seed', 'wager_reserve', 'wager_loss', 'wager_win', 'void_refund', 'manual_adjustment', 'boost_reward') NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    balance_before DECIMAL(15, 2) NOT NULL,
    balance_after DECIMAL(15, 2) NOT NULL,
    bet_id INT NULL,
    wager_id INT NULL,
    created_by_user_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    creator_user_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    visibility ENUM('friends', 'group', 'global_private_network') DEFAULT 'friends',
    status ENUM('draft', 'pending_review', 'approved', 'live', 'locked', 'result_proposed', 'settled', 'void', 'disputed', 'rejected') DEFAULT 'draft',
    is_boosted BOOLEAN DEFAULT FALSE,
    proof_required BOOLEAN DEFAULT TRUE,
    close_at TIMESTAMP NOT NULL,
    event_at TIMESTAMP NULL,
    result_outcome_id INT NULL,
    void_reason TEXT,
    review_submitted_at TIMESTAMP NULL,
    approved_at TIMESTAMP NULL,
    published_at TIMESTAMP NULL,
    locked_at TIMESTAMP NULL,
    settled_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (creator_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bet_outcomes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    bet_id INT NOT NULL,
    label VARCHAR(255) NOT NULL,
    coefficient DECIMAL(10, 2) NOT NULL,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (bet_id) REFERENCES bets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bet_versions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    bet_id INT NOT NULL,
    version_number INT NOT NULL,
    payload_json JSON NOT NULL,
    created_by_user_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (bet_id) REFERENCES bets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS wagers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    bet_id INT NOT NULL,
    user_id INT NOT NULL,
    outcome_id INT NOT NULL,
    stake DECIMAL(15, 2) NOT NULL,
    locked_coefficient DECIMAL(10, 2) NOT NULL,
    potential_return DECIMAL(15, 2) NOT NULL,
    status ENUM('active', 'won', 'lost', 'void', 'refunded') DEFAULT 'active',
    placed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    settled_at TIMESTAMP NULL,
    FOREIGN KEY (bet_id) REFERENCES bets(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (outcome_id) REFERENCES bet_outcomes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS result_proposals (
    id INT AUTO_INCREMENT PRIMARY KEY,
    bet_id INT NOT NULL,
    proposed_by_user_id INT NOT NULL,
    winning_outcome_id INT NOT NULL,
    proof_image_path VARCHAR(255),
    proof_text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (bet_id) REFERENCES bets(id) ON DELETE CASCADE,
    FOREIGN KEY (proposed_by_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (winning_outcome_id) REFERENCES bet_outcomes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS validation_votes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    bet_id INT NOT NULL,
    proposal_id INT NOT NULL,
    user_id INT NOT NULL,
    vote ENUM('approve', 'reject') NOT NULL,
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (bet_id) REFERENCES bets(id) ON DELETE CASCADE,
    FOREIGN KEY (proposal_id) REFERENCES result_proposals(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY (proposal_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS moderation_reviews (
    id INT AUTO_INCREMENT PRIMARY KEY,
    bet_id INT NOT NULL,
    review_type ENUM('publication', 'dispute', 'safety', 'override') NOT NULL,
    status ENUM('pending', 'approved', 'rejected', 'resolved') DEFAULT 'pending',
    moderator_user_id INT NULL,
    decision_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (bet_id) REFERENCES bets(id) ON DELETE CASCADE,
    FOREIGN KEY (moderator_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS reports (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reporter_user_id INT NOT NULL,
    bet_id INT NULL,
    reported_user_id INT NULL,
    reason VARCHAR(255) NOT NULL,
    notes TEXT,
    status ENUM('pending', 'reviewed', 'action_taken', 'dismissed') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (reporter_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS blocked_terms (
    id INT AUTO_INCREMENT PRIMARY KEY,
    term VARCHAR(100) NOT NULL,
    match_type ENUM('exact', 'contains', 'regex') DEFAULT 'contains',
    severity ENUM('warn', 'hold', 'reject') DEFAULT 'reject',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS leaderboard_snapshots (
    id INT AUTO_INCREMENT PRIMARY KEY,
    scope ENUM('global', 'friends', 'weekly') NOT NULL,
    user_id INT NOT NULL,
    bankroll DECIMAL(15, 2) NOT NULL,
    roi DECIMAL(10, 2) NOT NULL,
    win_rate DECIMAL(5, 2) NOT NULL,
    rank_position INT NOT NULL,
    snapshot_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS boosted_bets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    bet_id INT NOT NULL,
    boost_label VARCHAR(100),
    boost_multiplier DECIMAL(5, 2) DEFAULT 1.00,
    created_by_user_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (bet_id) REFERENCES bets(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    entity_type VARCHAR(50),
    entity_id INT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
