// Standard ELO (docs/framework.md §7), K=32.
const K = 32;

export function eloExpectedScore(ratingA: number, ratingB: number): number {
  return 1 / (1 + Math.pow(10, (ratingB - ratingA) / 400));
}

export function eloNewRating(rating: number, expected: number, actualScore: number): number {
  return Math.round(rating + K * (actualScore - expected));
}
