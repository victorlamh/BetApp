<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

Validator::validate($_POST, [
    'bet_id' => 'required|numeric',
    'proposal_id' => 'required|numeric',
    'vote' => 'required' // approve, reject
]);

$betId = (int)$_POST['bet_id'];
$proposalId = (int)$_POST['proposal_id'];
$vote = $_POST['vote'];
$userId = Auth::userId();

$db = DB::getInstance();

try {
    $db->beginTransaction();

    // 1. Check if user participated
    $wager = $db->fetchOne("SELECT id FROM wagers WHERE bet_id = ? AND user_id = ?", [$betId, $userId]);
    if (!$wager) throw new Exception("Only participants can validate results");

    // 2. Check if already voted
    $existingVote = $db->fetchOne("SELECT id FROM validation_votes WHERE proposal_id = ? AND user_id = ?", [$proposalId, $userId]);
    if ($existingVote) throw new Exception("You have already voted");

    // 3. Record vote
    $db->query(
        "INSERT INTO validation_votes (bet_id, proposal_id, user_id, vote, comment) VALUES (?, ?, ?, ?, ?)",
        [$betId, $proposalId, $userId, $vote, Security::sanitize($_POST['comment'] ?? '')]
    );

    // 4. Threshold Check
    $votes = $db->fetchAll("SELECT vote, COUNT(*) as count FROM validation_votes WHERE proposal_id = ? GROUP BY vote", [$proposalId]);
    $totalParticipants = $db->fetchOne("SELECT COUNT(*) as total FROM wagers WHERE bet_id = ?", [$betId])['total'];
    
    $approvals = 0;
    $rejections = 0;
    foreach ($votes as $v) {
        if ($v['vote'] === 'approve') $approvals = $v['count'];
        if ($v['vote'] === 'reject') $rejections = $v['count'];
    }

    $approvalRate = ($approvals / $totalParticipants) * 100;
    $rejectionRate = ($rejections / $totalParticipants) * 100;

    // Settlement Rules
    if ($approvalRate >= 60 || ($totalParticipants >= 2 && $approvals >= 2)) {
        // SETTLE
        settleBet($betId, $proposalId);
        $message = "Vote recorded. Threshold met. Bet settled!";
    } elseif ($rejectionRate >= 30) {
        // DISPUTE
        $db->query("UPDATE bets SET status = 'disputed' WHERE id = ?", [$betId]);
        $message = "Vote recorded. Bet marked as disputed due to high rejection rate.";
    } else {
        $message = "Vote recorded. Awaiting more validations.";
    }

    $db->commit();
    Response::success([], $message);

} catch (Exception $e) {
    $db->rollBack();
    Response::error($e->getMessage());
}

function settleBet($betId, $proposalId) {
    $db = DB::getInstance();
    $proposal = $db->fetchOne("SELECT winning_outcome_id FROM result_proposals WHERE id = ?", [$proposalId]);
    $winningOutcomeId = $proposal['winning_outcome_id'];

    // 1. Mark wagers
    $wagers = $db->fetchAll("SELECT * FROM wagers WHERE bet_id = ? FOR UPDATE", [$betId]);
    foreach ($wagers as $w) {
        $status = ($w['outcome_id'] == $winningOutcomeId) ? 'won' : 'lost';
        $db->query("UPDATE wagers SET status = ?, settled_at = NOW() WHERE id = ?", [$status, $w['id']]);

        if ($status === 'won') {
            // Payout
            $wallet = $db->fetchOne("SELECT balance FROM wallets WHERE user_id = ? FOR UPDATE", [$w['user_id']]);
            $newBalance = $wallet['balance'] + $w['potential_return'];
            $db->query("UPDATE wallets SET balance = ? WHERE user_id = ?", [$newBalance, $w['user_id']]);

            // Ledger
            $db->query(
                "INSERT INTO wallet_ledger (user_id, entry_type, amount, balance_before, balance_after, bet_id, wager_id, notes) 
                 VALUES (?, 'wager_win', ?, ?, ?, ?, ?, ?)",
                [$w['user_id'], $w['potential_return'], $wallet['balance'], $newBalance, $betId, $w['id'], "Winning payout for bet #$betId"]
            );
        } else {
            // Ledger for loss (record the loss of stake that was already reserved)
            $db->query(
                "INSERT INTO wallet_ledger (user_id, entry_type, amount, balance_before, balance_after, bet_id, wager_id, notes) 
                 VALUES (?, 'wager_loss', 0, ?, ?, ?, ?, ?)",
                [$w['user_id'], 0, 0, $betId, $w['id'], "Stake lost on bet #$betId"]
            );
        }
    }

    // 2. Update Bet
    $db->query("UPDATE bets SET status = 'settled', result_outcome_id = ?, settled_at = NOW() WHERE id = ?", [$winningOutcomeId, $betId]);
}
