<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

Validator::validate($_POST, [
    'bet_id' => 'required|numeric',
    'winning_outcome_id' => 'required|numeric'
]);

$betId = (int)$_POST['bet_id'];
$outcomeId = (int)$_POST['winning_outcome_id'];
$userId = Auth::userId();

$db = DB::getInstance();

try {
    $db->beginTransaction();

    $bet = $db->fetchOne("SELECT creator_user_id, status FROM bets WHERE id = ? FOR UPDATE", [$betId]);
    if (!$bet) throw new Exception("Bet not found");

    if ($bet['creator_user_id'] != $userId && Auth::user()['role'] === 'player') {
        throw new Exception("Unauthorized to propose result");
    }

    if (!in_array($bet['status'], ['live', 'locked'])) {
        throw new Exception("Bet status is not eligible for result proposal");
    }

    // Insert Proposal
    $db->query(
        "INSERT INTO result_proposals (bet_id, proposed_by_user_id, winning_outcome_id, proof_text) 
         VALUES (?, ?, ?, ?)",
        [$betId, $userId, $outcomeId, Security::sanitize($_POST['proof_text'] ?? '')]
    );

    // Update Bet status
    $db->query("UPDATE bets SET status = 'result_proposed' WHERE id = ?", [$betId]);

    $db->commit();
    Response::success([], "Result proposed. Awaiting participant validation.");

} catch (Exception $e) {
    $db->rollBack();
    Response::error($e->getMessage());
}
