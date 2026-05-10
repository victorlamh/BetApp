<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireRole(['admin', 'moderator']);

Validator::validate($_POST, [
    'bet_id' => 'required|numeric',
    'winning_outcome_id' => 'required|numeric'
]);

$betId = (int)$_POST['bet_id'];
$winningOutcomeId = (int)$_POST['winning_outcome_id'];
$db = DB::getInstance();

try {
    $db->beginTransaction();

    // 1. Fetch bet and verify it's not already settled
    $bet = $db->fetchOne("SELECT title, status FROM bets WHERE id = ? FOR UPDATE", [$betId]);
    if (!$bet) throw new Exception("Bet not found");
    if ($bet['status'] === 'settled') throw new Exception("Bet is already settled");

    // 2. Fetch all wagers for this bet
    $wagers = $db->fetchAll("SELECT * FROM wagers WHERE bet_id = ? AND status = 'active'", [$betId]);

    foreach ($wagers as $wager) {
        $wagerId = $wager['id'];
        $userId = $wager['user_id'];
        $stake = (float)$wager['stake'];
        $lockedCoeff = (float)$wager['locked_coefficient'];
        $potentialReturn = (float)$wager['potential_return'];

        if ((int)$wager['outcome_id'] === $winningOutcomeId) {
            // WINNER
            $wallet = $db->fetchOne("SELECT balance FROM wallets WHERE user_id = ? FOR UPDATE", [$userId]);
            $newBalance = $wallet['balance'] + $potentialReturn;

            $db->query("UPDATE wallets SET balance = ? WHERE user_id = ?", [$newBalance, $userId]);
            $db->query(
                "INSERT INTO wallet_ledger (user_id, entry_type, amount, balance_before, balance_after, bet_id, wager_id, notes) 
                 VALUES (?, 'wager_win', ?, ?, ?, ?, ?, ?)",
                [$userId, $potentialReturn, $wallet['balance'], $newBalance, $betId, $wagerId, "Winning payout for bet #$betId"]
            );
            $db->query("UPDATE wagers SET status = 'won' WHERE id = ?", [$wagerId]);
            
            // Notification
            $db->query(
                "INSERT INTO notifications (user_id, type, target_id, message) VALUES (?, 'bet_settled', ?, ?)",
                [$userId, $betId, "🎉 WINNER! You won " . number_format($potentialReturn, 2) . "€ on: " . $bet['title']]
            );
        } else {
            // LOSER
            $db->query("UPDATE wagers SET status = 'lost' WHERE id = ?", [$wagerId]);
            
            // Notification
            $db->query(
                "INSERT INTO notifications (user_id, type, target_id, message) VALUES (?, 'bet_settled', ?, ?)",
                [$userId, $betId, "😔 You lost " . number_format($stake, 2) . "€ on: " . $bet['title']]
            );
        }
    }

    // 3. Mark bet as settled
    $db->query(
        "UPDATE bets SET status = 'settled', result_outcome_id = ?, settled_at = NOW() WHERE id = ?",
        [$winningOutcomeId, $betId]
    );

    $db->commit();
    Response::success(null, "Bet settled successfully. Winnings distributed.");

} catch (Exception $e) {
    $db->rollBack();
    Response::error($e->getMessage());
}
