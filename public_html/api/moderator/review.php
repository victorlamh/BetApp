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

// Prevent double-processing
$currentBet = $db->fetchOne("SELECT status FROM bets WHERE id = ?", [$betId]);
if (!$currentBet) {
    Response::error("Bet not found", 404);
}

if ($currentBet['status'] !== 'pending_review') {
    Response::success(['status' => 'already_processed', 'current_status' => $currentBet['status']], "Bet already processed");
}

try {
    $db->beginTransaction();

    $newStatus = ($action === 'approve') ? 'live' : 'rejected';
    $reviewStatus = ($action === 'approve') ? 'approved' : 'rejected';

    // 1. Update the bet status
    $db->query("UPDATE bets SET status = ? WHERE id = ?", [$newStatus, $betId]);

    // 2. Update moderation review if it exists
    $existing = $db->fetchOne("SELECT id FROM moderation_reviews WHERE bet_id = ? AND status = 'pending'", [$betId]);
    if ($existing) {
        $db->query(
            "UPDATE moderation_reviews SET status = ?, moderator_user_id = ?, decision_reason = ?, updated_at = NOW() WHERE id = ?",
            [$reviewStatus, Auth::userId(), $notes, $existing['id']]
        );
    } else {
        $db->query(
            "INSERT INTO moderation_reviews (bet_id, review_type, status, moderator_user_id, decision_reason) VALUES (?, 'publication', ?, ?, ?)",
            [$betId, $reviewStatus, Auth::userId(), $notes]
        );
    }

    // 3. Notify the creator
    $bet = $db->fetchOne("SELECT creator_user_id, title FROM bets WHERE id = ?", [$betId]);
    if ($bet) {
        $msg = ($action === 'approve')
            ? "Your bet '{$bet['title']}' has been approved and is now live!"
            : "Your bet '{$bet['title']}' was rejected.";
        $db->query(
            "INSERT INTO notifications (user_id, type, message, related_id) VALUES (?, ?, ?, ?)",
            [$bet['creator_user_id'], $action === 'approve' ? 'bet_approved' : 'bet_rejected', $msg, $betId]
        );
    }

    $db->commit();
    file_put_contents(__DIR__ . '/../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] review.php SUCCESS - bet $betId $action\n", FILE_APPEND);
    Response::success(['status' => 'ok', 'bet_id' => $betId, 'action' => $action], "Bet " . ($action === 'approve' ? "approved and is now live" : "rejected"));

} catch (Exception $e) {
    $db->rollBack();
    file_put_contents(__DIR__ . '/../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] review.php SQL ERROR: " . $e->getMessage() . "\n", FILE_APPEND);
    Response::error("Failed: " . $e->getMessage());
}
