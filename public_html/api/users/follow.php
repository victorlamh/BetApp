<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

$action = $_POST['action'] ?? ''; // 'request', 'accept', 'refuse', 'unfollow'
$targetId = (int)($_POST['user_id'] ?? 0);

if (!$targetId) {
    Response::error("Target user ID required");
}

$db = DB::getInstance();
$currentUserId = Auth::userId();

file_put_contents(__DIR__ . '/../../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] follow.php: userId=$currentUserId action=$action targetId=$targetId\n", FILE_APPEND);

switch ($action) {
    case 'request':
        try {
            $db->query(
                "INSERT INTO follows (follower_id, followed_id, status) VALUES (?, ?, 'pending')",
                [$currentUserId, $targetId]
            );
            
            // Notify target user
            $db->query(
                "INSERT INTO notifications (user_id, type, message, related_id) VALUES (?, 'follow_request', ?, ?)",
                [$targetId, "New follow request from " . Auth::user()['username'], $currentUserId]
            );
            
            Response::success((object)[], "Follow request sent");
        } catch (Exception $e) {
            Response::error("Already following or request pending");
        }
        break;

    case 'accept':
        $db->query(
            "UPDATE follows SET status = 'accepted' WHERE follower_id = ? AND followed_id = ?",
            [$targetId, $currentUserId]
        );
        
        $count = $db->rowCount();
        file_put_contents(__DIR__ . '/../../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] follow.php ACCEPT: affected=$count targetId=$targetId currentUserId=$currentUserId\n", FILE_APPEND);
        
        if ($count > 0) {
            // Notify requester
            $db->query(
                "INSERT INTO notifications (user_id, type, message, related_id) VALUES (?, 'follow_accepted', ?, ?)",
                [$targetId, Auth::user()['username'] . " accepted your follow request", $currentUserId]
            );
            Response::success((object)[], "Follow request accepted");
        } else {
            Response::error("No pending request found");
        }
        break;

    case 'refuse':
        $db->query(
            "DELETE FROM follows WHERE follower_id = ? AND followed_id = ? AND status = 'pending'",
            [$targetId, $currentUserId]
        );
        $count = $db->rowCount();
        file_put_contents(__DIR__ . '/../../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] follow.php REFUSE: affected=$count targetId=$targetId currentUserId=$currentUserId\n", FILE_APPEND);
        Response::success((object)[], "Request refused");
        break;

    case 'unfollow':
        $db->query(
            "DELETE FROM follows WHERE follower_id = ? AND followed_id = ?",
            [$currentUserId, $targetId]
        );
        Response::success((object)[], "Unfollowed user");
        break;

    default:
        Response::error("Invalid action");
}
