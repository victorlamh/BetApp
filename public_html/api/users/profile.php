<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

$db = DB::getInstance();
$userId = Auth::userId();

// Get counts
$followers = $db->fetchOne("SELECT COUNT(*) as count FROM follows WHERE followed_id = ? AND status = 'accepted'", [$userId]);
$following = $db->fetchOne("SELECT COUNT(*) as count FROM follows WHERE follower_id = ? AND status = 'accepted'", [$userId]);
$wallet = $db->fetchOne("SELECT balance FROM wallets WHERE user_id = ?", [$userId]);

Response::success([
    'user' => [
        'id' => $userId,
        'username' => Auth::user()['username'],
        'display_name' => Auth::user()['display_name'],
        'avatar_url' => Auth::user()['avatar_url']
    ],
    'stats' => [
        'followers_count' => (int)$followers['count'],
        'following_count' => (int)$following['count'],
        'wallet_balance' => (float)$wallet['balance']
    ]
]);
