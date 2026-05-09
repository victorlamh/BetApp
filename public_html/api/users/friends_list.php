<?php
// api/users/friends_list.php
require_once __DIR__ . '/../bootstrap.php';
Auth::requireAuth();

$userId = Auth::userId();
$db = DB::getInstance();

$friends = $db->fetchAll(
    "SELECT u.id, u.username, u.display_name, f.status 
     FROM friendships f 
     JOIN users u ON (f.requester_id = u.id OR f.addressee_id = u.id)
     WHERE (f.requester_id = ? OR f.addressee_id = ?) 
     AND u.id != ? AND f.status = 'accepted'",
    [$userId, $userId, $userId]
);

$pending = $db->fetchAll(
    "SELECT u.id, u.username, u.display_name, f.id as request_id
     FROM friendships f 
     JOIN users u ON f.requester_id = u.id 
     WHERE f.addressee_id = ? AND f.status = 'pending'",
    [$userId]
);

Response::success(['friends' => $friends, 'pending_incoming' => $pending]);
