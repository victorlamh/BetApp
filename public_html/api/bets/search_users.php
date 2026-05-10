<?php
// Alternative path for user search in case api/users/ is blocked
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

$query = Security::sanitize($_GET['q'] ?? '');
if (strlen($query) < 2) {
    Response::success([], "Search query too short");
}

$db = DB::getInstance();
$currentUserId = Auth::userId();

$sql = "SELECT id, username, display_name, avatar_url,
        (SELECT status FROM follows WHERE follower_id = ? AND followed_id = users.id) as follow_status
        FROM users 
        WHERE id != ? 
        AND status = 'active'";

try {
    if ($query === '*all') {
        $users = $db->fetchAll($sql . " LIMIT 100", [$currentUserId, $currentUserId]);
    } else {
        $users = $db->fetchAll(
            $sql . " AND (username LIKE ? OR display_name LIKE ?) LIMIT 20",
            [$currentUserId, $currentUserId, "%$query%", "%$query%"]
        );
    }

    file_put_contents(__DIR__ . '/../../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] search_users: query='$query' userId=$currentUserId found=" . count($users) . "\n", FILE_APPEND);

    foreach ($users as &$user) {
        $user['id'] = (int)$user['id'];
    }

    Response::success($users);
} catch (Exception $e) {
    file_put_contents(__DIR__ . '/../../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] search_users ERROR: " . $e->getMessage() . "\n", FILE_APPEND);
    Response::error($e->getMessage(), 500);
}
