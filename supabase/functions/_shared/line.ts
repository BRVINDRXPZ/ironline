// Shared helpers for THE LINE calculations (calculate-line, line-score).
export function estimatedOneRepMax(weight: number, reps: number): number {
  return weight * (1 + reps / 30);
}

export function predictedWeightFor(e1RM: number, reps: number): number {
  return e1RM / (1 + reps / 30);
}
