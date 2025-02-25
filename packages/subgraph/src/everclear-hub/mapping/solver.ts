import { IncreaseVirtualBalanceSet, SolverConfigUpdated } from '../../../generated/EverclearHub/EverclearHub';
import { Solver } from '../../../generated/schema';

/**
 * Creates subgraph records when SolverConfigUpdated events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleSolverConfigUpdated(event: SolverConfigUpdated): void {
  const id = event.params._solver;
  let solver = Solver.load(id);
  if (solver == null) {
    solver = new Solver(id);
    solver.updateVirtualBalance = false;
  }

  solver.supportedDomains = event.params._supportedDomains || [];
  solver.save();
}

/**
 * Creates subgraph records when IncreaseVirtualBalanceSet events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleIncreaseVirtualBalanceSet(event: IncreaseVirtualBalanceSet): void {
  const id = event.params._user;
  let solver = Solver.load(id);
  if (solver == null) {
    solver = new Solver(id);
    solver.supportedDomains = [];
  }

  solver.updateVirtualBalance = event.params._status;
  solver.save();
}
