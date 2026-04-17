const K_FACTOR = 32;
const MIN_ELO = 100;

export interface EloCalculationInput {
  currentElo: number;
  riskScore: number;
  completedMicrotask: boolean;
}

export interface EloCalculationResult {
  newElo: number;
  delta: number;
  expectedScore: number;
  actualScore: number;
  challengeElo: number;
}

const clamp = (value: number, min: number, max: number): number => {
  return Math.min(max, Math.max(min, value));
};

export const calculateElo = ({
  currentElo,
  riskScore,
  completedMicrotask
}: EloCalculationInput): EloCalculationResult => {
  const normalizedRisk = clamp(riskScore, 0, 10) / 10;

  // Higher risk means a harder recovery challenge and therefore a higher opponent ELO.
  const challengeElo = 1000 + normalizedRisk * 400;
  const expectedScore = 1 / (1 + Math.pow(10, (challengeElo - currentElo) / 400));

  const actualScore = completedMicrotask
    ? 0.6 + (1 - normalizedRisk) * 0.4
    : 0.2 + (1 - normalizedRisk) * 0.2;

  const delta = Math.round(K_FACTOR * (actualScore - expectedScore));
  const newElo = Math.max(MIN_ELO, Math.round(currentElo + delta));

  return {
    newElo,
    delta,
    expectedScore,
    actualScore,
    challengeElo
  };
};
