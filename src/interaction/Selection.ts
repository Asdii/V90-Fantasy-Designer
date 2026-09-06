export interface SelectionState {
  readonly selectedFacetId?: number;
  readonly hoveredFacetId?: number;
}

export const emptySelection: SelectionState = {
  selectedFacetId: undefined,
  hoveredFacetId: undefined,
};
