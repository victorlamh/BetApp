<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

Validator::validate($_POST, [
    'bet_id' => 'required|numeric',
    'outcome_id' => 'required|numeric',
    'stake' => 'required|numeric'
]);

$betId = (int)$_POST['bet_id'];
$outcomeId = (int)$_POST['outcome_id'];
$stake = (float)$_POST['stake'];
$userId = Auth::userId();

if ($stake <= 0) Response::error("Stake must be positive");

$db = DB::getInstance();

try {
    $db->beginTransaction();

    // 1. Lock user's wallet for update
    $wallet = $db->fetchOne("SELECT balance FROM wallets WHERE user_id = ? FOR UPDATE", [$userId]);
    if ($wallet['balance'] < $stake) {
        throw new Exception("Insufficient balance");
    }

    // 2. Verify bet state
    $bet = $db->fetchOne("SELECT status, close_at FROM bets WHERE id = ? FOR UPDATE", [$betId]);
    if (!$bet || $bet['status'] !== 'live') {
        throw new Exception("Bet is not live");
    }
    if (strtotime($bet['close_at']) <= time()) {
        throw new Exception("Bet is closed for wagering");
    }

    // 3. Verify outcome
    $outcome = $db->fetchOne("SELECT coefficient FROM bet_outcomes WHERE id = ? AND bet_id = ?", [$outcomeId, $betId]);
    if (!$outcome) {
        throw new Exception("Invalid outcome");
    }

    // 4. Check if already wagered
    $existing = $db->fetchOne("SELECT id FROM wagers WHERE bet_id = ? AND user_id = ?", [$betId, $userId]);
    if ($existing) {
        throw new Exception("You have already placed a wager on this bet");
    }

    // 5. Deduct balance
    $newBalance = $wallet['balance'] - $stake;
    $db->query("UPDATE wallets SET balance = ? WHERE user_id = ?", [$newBalance, $userId]);

    // 6. Record Ledger
    $db->query(
        "INSERT INTO wallet_ledger (user_id, entry_type, amount, balance_before, balance_after, bet_id, notes) 
         VALUES (?, 'wager_reserve', ?, ?, ?, ?, ?)",
        [$userId, -$stake, $wallet['balance'], $newBalance, $betId, "Wager on bet #$betId"]
    );

    // 7. Insert Wager
    $potentialReturn = $stake * $outcome['coefficient'];
    $db->query(
        "INSERT INTO wagers (bet_id, user_id, outcome_id, stake, locked_coefficient, potential_return) 
         VALUES (?, ?, ?, ?, ?, ?)",
        [$betId, $userId, $outcomeId, $stake, $outcome['coefficient'], $potentialReturn]
    );

    $db->commit();
    Response::success([
        'new_balance' => $newBalance,
        'potential_return' => $potentialReturn
    ], "Wager placed successfully");

} catch (Exception $e) {
    $db->rollBack();
    Response::error($e->getMessage());
}
