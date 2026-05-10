<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

$db = DB::getInstance();
$userId = Auth::userId();

// Fetch latest notifications
$notifications = $db->fetchAll(
    "SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 50",
    [$userId]
);

// Format IDs
foreach ($notifications as &$n) {
    $n['id'] = (int)$n['id'];
    $n['user_id'] = (int)$n['user_id'];
    $n['related_id'] = $n['related_id'] ? (int)$n['related_id'] : null;
    $n['is_read'] = (bool)$n['is_read'];
    
    // Check if current user is following the requester back
    $n['is_following_back'] = false;
    if ($n['type'] === 'follow_request' && $n['related_id']) {
        $check = $db->fetchOne(
            "SELECT 1 FROM follows WHERE follower_id = ? AND followed_id = ?",
            [$userId, $n['related_id']]
        );
        $n['is_following_back'] = (bool)$check;
    }
    
    file_put_contents(__DIR__ . '/../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] Notification: ID={$n['id']} Type={$n['type']} Related=" . ($n['related_id'] ?? 'NULL') . " FollowingBack=" . ($n['is_following_back'] ? 'YES' : 'NO') . "\n", FILE_APPEND);
}

Response::success($notifications);
