<?php
class Odds {
    private const SEED_AMOUNT = 100.00; // The virtual money used to stabilize initial odds

    /**
     * Calculates the real-time dynamic coefficient for an outcome.
     * Formula: (Total_Pool + Seed) / (Outcome_Pool + Seed / Initial_Coefficient)
     */
    public static function calculate($betId, $outcomes) {
        $totalRealWagered = 0;
        foreach ($outcomes as $o) {
            $totalRealWagered += (float)($o['total_wagered'] ?? 0);
        }

        $totalPool = $totalRealWagered + self::SEED_AMOUNT;
        
        $results = [];
        foreach ($outcomes as $outcome) {
            $initialCoeff = (float)$outcome['initial_coefficient'];
            $outcomeRealWagered = (float)($outcome['total_wagered'] ?? 0);
            
            // The "virtual" seed for this specific outcome is calculated 
            // so that at zero real bets, the result equals the initial_coefficient.
            $safeInitialCoeff = $initialCoeff > 0 ? $initialCoeff : 1.0;
            $outcomeSeed = self::SEED_AMOUNT / $safeInitialCoeff;
            
            $currentCoeff = $totalPool / ($outcomeRealWagered + $outcomeSeed);
            
            // Floor it to 1.01 to prevent negative or zero odds
            $currentCoeff = max(1.01, round($currentCoeff, 2));
            
            $outcome['coefficient'] = $currentCoeff;
            $results[] = $outcome;
        }
        
        return $results;
    }
}
