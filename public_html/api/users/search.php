<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

$query = Security::sanitize($_GET['q'] ?? '');
if (strlen($query) < 2) {
    Response::success([], "Search query too short");
}

$db = DB::getInstance();
$currentUserId = Auth::userId();

// Search users by username or display name, excluding self
$users = $db->fetchAll(
    "SELECT id, username, display_name, avatar_url,
     (SELECT status FROM follows WHERE follower_id = ? AND followed_id = users.id) as follow_status
     FROM users 
     WHERE (username LIKE ? OR display_name LIKE ?) 
     AND id != ? 
     AND status = 'active'
     LIMIT 20",
    [$currentUserId, "%$query%", "%$query%", $currentUserId]
);

// Format numeric IDs
foreach ($users as &$user) {
    $user['id'] = (int)$user['id'];
}

Response::success($users);
