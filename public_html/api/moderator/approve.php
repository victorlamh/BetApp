<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireRole(['moderator', 'admin']);

Validator::validate($_POST, ['bet_id' => 'required|numeric']);

$betId = (int)$_POST['bet_id'];
$db = DB::getInstance();

try {
    $db->beginTransaction();

    $db->query(
        "UPDATE bets SET status = 'live', approved_at = NOW(), published_at = NOW() WHERE id = ?",
        [$betId]
    );

    $db->query(
        "UPDATE moderation_reviews SET status = 'approved', moderator_user_id = ?, updated_at = NOW() 
         WHERE bet_id = ? AND review_type = 'publication' AND status = 'pending'",
        [Auth::userId(), $betId]
    );

    $db->commit();
    Response::success([], "Bet approved and is now live");

} catch (Exception $e) {
    $db->rollBack();
    Response::error($e->getMessage());
}
