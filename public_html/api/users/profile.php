<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

$db = DB::getInstance();
$userId = Auth::userId();
file_put_contents(__DIR__ . '/../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] Profile Fetch for User ID: $userId\n", FILE_APPEND);

// Get counts
$followers = $db->fetchOne("SELECT COUNT(*) as count FROM follows WHERE followed_id = ? AND status = 'accepted'", [$userId]);
$following = $db->fetchOne("SELECT COUNT(*) as count FROM follows WHERE follower_id = ? AND status = 'accepted'", [$userId]);
$wallet = $db->fetchOne("SELECT balance FROM wallets WHERE user_id = ?", [$userId]);

if (!$wallet) {
    file_put_contents(__DIR__ . '/../debug_log.txt', "WALLET MISSING for User $userId. Initializing...\n", FILE_APPEND);
    $db->query("INSERT IGNORE INTO wallets (user_id, balance) VALUES (?, 100.00)", [$userId]);
    $wallet = ['balance' => 100.00];
}

file_put_contents(__DIR__ . '/../debug_log.txt', "BALANCE FOUND for User $userId: " . $wallet['balance'] . "\n", FILE_APPEND);

Response::success([
    'user' => [
        'id' => $userId,
        'username' => Auth::user()['username'],
        'display_name' => Auth::user()['display_name'],
        'role' => Auth::user()['role'],
        'avatar_url' => Auth::user()['avatar_url']
    ],
    'stats' => [
        'followers_count' => (int)$followers['count'],
        'following_count' => (int)$following['count'],
        'wallet_balance' => (float)$wallet['balance']
    ]
]);
