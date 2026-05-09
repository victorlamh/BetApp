<?php
require_once __DIR__ . '/../bootstrap.php';

// Allow both Admins and Moderators
Auth::requireAuth();
if (!in_array(Auth::user()['role'], ['admin', 'moderator'])) {
    Response::forbidden();
}

// Read from merged POST (bootstrap already parsed JSON body into $_POST)
$betId  = (int)($_POST['bet_id'] ?? 0);
$action = $_POST['action'] ?? '';
$notes  = Security::sanitize($_POST['notes'] ?? 'Moderated via App');

// Log for debugging
file_put_contents(__DIR__ . '/../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] review.php - betId=$betId action=$action POST=" . json_encode($_POST) . "\n", FILE_APPEND);

if (!$betId || !in_array($action, ['approve', 'reject'])) {
    Response::error("Missing or invalid bet_id or action. Got: betId=$betId, action=$action", 400);
}


$db = DB::getInstance();

try {
    $db->beginTransaction();

    if ($action === 'approve') {
        $db->query("UPDATE bets SET status = 'live' WHERE id = ?", [$betId]);
        $status = 'approved';
    } else {
        $db->query("UPDATE bets SET status = 'rejected' WHERE id = ?", [$betId]);
        $status = 'rejected';
    }

    // Update moderation review record
    $db->query(
        "UPDATE moderation_reviews SET status = ?, moderator_id = ?, notes = ?, reviewed_at = NOW() 
         WHERE bet_id = ? AND status = 'pending' LIMIT 1",
        [$status, Auth::userId(), $notes, $betId]
    );

    // Notify the creator
    $bet = $db->fetchOne("SELECT creator_user_id, title FROM bets WHERE id = ?", [$betId]);
    if ($bet) {
        $msg = $action === 'approve' ? "Your bet '{$bet['title']}' has been approved!" : "Your bet '{$bet['title']}' was rejected.";
        $db->query(
            "INSERT INTO notifications (user_id, type, message, related_id) VALUES (?, ?, ?, ?)",
            [$bet['creator_user_id'], $action === 'approve' ? 'bet_approved' : 'bet_rejected', $msg, $betId]
        );
    }

    $db->commit();
    Response::success(null, "Bet " . ($action === 'approve' ? "approved" : "rejected"));

} catch (Exception $e) {
    $db->rollBack();
    Response::error($e->getMessage());
}
