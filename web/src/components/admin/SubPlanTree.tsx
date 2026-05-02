'use client';

import { useState, useCallback, useRef } from 'react';
import type { PlanTreeNode } from '@/types/plan-detail';

// ────────────────────────────────────────────────────────────────────────────
// Types
// ────────────────────────────────────────────────────────────────────────────

export interface SubPlanTreeProps {
  /** Plan UUID of the root plan */
  planId: string;
  /** Root tree node with recursive children */
  tree: PlanTreeNode;
  /** Callback after reorder — parent can refresh data */
  onReordered?: () => void;
}

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

const MAX_DEPTH = 3;

const INDENT_CLASSES: Record<number, string> = {
  0: 'ml-0',
  1: 'ml-6',
  2: 'ml-12',
};

// ────────────────────────────────────────────────────────────────────────────
// Component
// ────────────────────────────────────────────────────────────────────────────

/**
 * SubPlanTree — client component
 *
 * Renders a recursive sub-plan hierarchy with drag-and-drop reorder.
 * Uses native HTML5 Drag & Drop API (no additional libraries needed).
 *
 * Depth-3 validation: if a drag would result in a 4th-level nesting,
 * the drop is rejected and a 422 toast is shown (AC-011).
 *
 * Reorder calls PATCH /api/admin/plans/:id { parentPlanId, position }
 * for the moved node.
 *
 * Accessibility:
 *  - Tree rendered as a nested list with role="tree" / role="treeitem"
 *  - Drag handle has aria-label
 *  - Error messages use role="alert"
 *  - Visual depth indicators via indentation
 */
export default function SubPlanTree({
  planId,
  tree,
  onReordered,
}: SubPlanTreeProps) {
  const [treeData, setTreeData] = useState<PlanTreeNode>(tree);
  const [saving, setSaving] = useState(false);
  const [toasts, setToasts] = useState<
    Array<{ id: string; message: string; type: 'success' | 'error' }>
  >([]);

  const draggedNodeId = useRef<string | null>(null);
  const dragOverNodeId = useRef<string | null>(null);

  const dismissToast = useCallback((toastId: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== toastId));
  }, []);

  const addToast = useCallback(
    (message: string, type: 'success' | 'error') => {
      const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
      setToasts((prev) => [...prev, { id, message, type }]);
      setTimeout(() => dismissToast(id), 5000);
    },
    [dismissToast],
  );

  // ── Helper: find a node and its parent ────────────────────────────────

  const findNodeAndParent = useCallback(
    (
      node: PlanTreeNode,
      targetId: string,
      parent: PlanTreeNode | null = null,
    ): { node: PlanTreeNode; parent: PlanTreeNode | null } | null => {
      if (node.id === targetId) return { node, parent };
      for (const child of node.children) {
        const result = findNodeAndParent(child, targetId, node);
        if (result) return result;
      }
      return null;
    },
    [],
  );

  // ── Helper: compute max descendant depth ──────────────────────────────

  const getMaxDescendantDepth = useCallback(
    (node: PlanTreeNode): number => {
      if (node.children.length === 0) return 0;
      return (
        1 +
        Math.max(...node.children.map((c) => getMaxDescendantDepth(c)))
      );
    },
    [],
  );

  // ── Helper: compute depth of a node in the tree ───────────────────────

  const getNodeDepth = useCallback(
    (root: PlanTreeNode, targetId: string, currentDepth = 0): number => {
      if (root.id === targetId) return currentDepth;
      for (const child of root.children) {
        const depth = getNodeDepth(child, targetId, currentDepth + 1);
        if (depth !== -1) return depth;
      }
      return -1;
    },
    [],
  );

  // ── Drag event handlers ───────────────────────────────────────────────

  const handleDragStart = useCallback(
    (e: React.DragEvent<HTMLLIElement>, nodeId: string) => {
      draggedNodeId.current = nodeId;
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/plain', nodeId);
    },
    [],
  );

  const handleDragOver = useCallback(
    (e: React.DragEvent<HTMLLIElement>, nodeId: string) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      dragOverNodeId.current = nodeId;
    },
    [],
  );

  const handleDragLeave = useCallback(() => {
    dragOverNodeId.current = null;
  }, []);

  const handleDrop = useCallback(
    async (e: React.DragEvent<HTMLLIElement>, targetNodeId: string) => {
      e.preventDefault();
      e.stopPropagation();

      const sourceId = draggedNodeId.current;
      draggedNodeId.current = null;
      dragOverNodeId.current = null;

      if (!sourceId || sourceId === targetNodeId) return;

      // Don't drop onto self or root
      if (targetNodeId === treeData.id && sourceId === treeData.id) return;

      // Check depth constraint: target depth + source subtree depth + 1 must be <= MAX_DEPTH
      const targetDepth = getNodeDepth(treeData, targetNodeId);
      const sourceResult = findNodeAndParent(treeData, sourceId);

      if (targetDepth === -1 || !sourceResult) return;

      const sourceSubtreeDepth = getMaxDescendantDepth(sourceResult.node);
      const totalDepth = targetDepth + 1 + sourceSubtreeDepth;

      if (totalDepth > MAX_DEPTH) {
        // 422 depth validation error — show toast (AC-011)
        addToast(
          'Cannot nest beyond 3 levels. Maximum hierarchy depth would be exceeded.',
          'error',
        );
        return;
      }

      // Find target's children to compute position
      const targetResult = findNodeAndParent(treeData, targetNodeId);
      if (!targetResult) return;

      const newPosition = targetResult.node.children.length;

      setSaving(true);

      try {
        const res = await fetch(`/api/admin/plans/${sourceId}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            parentPlanId: targetNodeId,
            position: newPosition,
          }),
        });

        if (res.status === 422) {
          // Backend depth validation rejected the move
          const body = await res.json().catch(() => ({}));
          const msg =
            typeof body?.error === 'string'
              ? body.error
              : 'Cannot nest beyond 3 levels.';
          addToast(msg, 'error');
          return;
        }

        if (!res.ok) {
          addToast('Failed to reorder. Please try again.', 'error');
          return;
        }

        // Optimistically move the node in local state
        const removeNode = (
          parent: PlanTreeNode,
          id: string,
        ): { updated: PlanTreeNode; removed: PlanTreeNode | null } => {
          const idx = parent.children.findIndex((c) => c.id === id);
          if (idx !== -1) {
            const removed = parent.children[idx];
            return {
              updated: {
                ...parent,
                children: [
                  ...parent.children.slice(0, idx),
                  ...parent.children.slice(idx + 1),
                ],
              },
              removed,
            };
          }
          let removedNode: PlanTreeNode | null = null;
          const newChildren = parent.children.map((child) => {
            if (removedNode) return child;
            const result = removeNode(child, id);
            if (result.removed) {
              removedNode = result.removed;
              return result.updated;
            }
            return child;
          });
          return {
            updated: { ...parent, children: newChildren },
            removed: removedNode,
          };
        };

        const addNode = (
          parent: PlanTreeNode,
          targetId: string,
          node: PlanTreeNode,
        ): PlanTreeNode => {
          if (parent.id === targetId) {
            return {
              ...parent,
              children: [
                ...parent.children,
                {
                  ...node,
                  parentPlanId: targetId,
                  depth: parent.depth + 1,
                  position: parent.children.length,
                },
              ],
            };
          }
          return {
            ...parent,
            children: parent.children.map((c) =>
              addNode(c, targetId, node),
            ),
          };
        };

        const { updated, removed } = removeNode(treeData, sourceId);
        if (removed) {
          setTreeData(addNode(updated, targetNodeId, removed));
        }

        addToast('Sub-plan moved successfully.', 'success');
        onReordered?.();
      } catch {
        addToast('Network error. Please try again.', 'error');
      } finally {
        setSaving(false);
      }
    },
    [
      treeData,
      getNodeDepth,
      findNodeAndParent,
      getMaxDescendantDepth,
      addToast,
      onReordered,
    ],
  );

  // ── Reorder within same parent (move up/down) ────────────────────────

  const handleReorderWithinParent = useCallback(
    async (nodeId: string, direction: 'up' | 'down') => {
      const result = findNodeAndParent(treeData, nodeId);
      if (!result || !result.parent) return;

      const siblings = result.parent.children;
      const currentIndex = siblings.findIndex((c) => c.id === nodeId);
      if (currentIndex === -1) return;

      const newIndex =
        direction === 'up' ? currentIndex - 1 : currentIndex + 1;
      if (newIndex < 0 || newIndex >= siblings.length) return;

      setSaving(true);

      try {
        const res = await fetch(`/api/admin/plans/${nodeId}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            parentPlanId: result.parent.id,
            position: newIndex,
          }),
        });

        if (!res.ok) {
          addToast('Failed to reorder. Please try again.', 'error');
          return;
        }

        // Optimistically reorder in local state
        const updateSiblings = (parent: PlanTreeNode): PlanTreeNode => {
          if (parent.id === result.parent!.id) {
            const newSiblings = [...parent.children];
            const [moved] = newSiblings.splice(currentIndex, 1);
            newSiblings.splice(newIndex, 0, {
              ...moved,
              position: newIndex,
            });
            return {
              ...parent,
              children: newSiblings.map((c, i) => ({
                ...c,
                position: i,
              })),
            };
          }
          return {
            ...parent,
            children: parent.children.map(updateSiblings),
          };
        };

        setTreeData(updateSiblings(treeData));
        onReordered?.();
      } catch {
        addToast('Network error. Please try again.', 'error');
      } finally {
        setSaving(false);
      }
    },
    [treeData, findNodeAndParent, addToast, onReordered],
  );

  // ── Render tree node recursively ──────────────────────────────────────

  const renderNode = (
    node: PlanTreeNode,
    isRoot = false,
    siblingCount = 1,
    siblingIndex = 0,
  ): React.ReactNode => {
    const depthClass = INDENT_CLASSES[node.depth] ?? 'ml-12';
    const hasChildren = node.children.length > 0;

    return (
      <li
        key={node.id}
        role="treeitem"
        aria-expanded={hasChildren ? true : undefined}
        aria-level={node.depth + 1}
        aria-setsize={siblingCount}
        aria-posinset={siblingIndex + 1}
        draggable={!isRoot && !saving}
        onDragStart={(e) => handleDragStart(e, node.id)}
        onDragOver={(e) => handleDragOver(e, node.id)}
        onDragLeave={handleDragLeave}
        onDrop={(e) => { void handleDrop(e, node.id); }}
        className={`${depthClass} transition-colors`}
      >
        <div
          className={`flex items-center gap-2 rounded-lg px-3 py-2 ${
            isRoot
              ? 'bg-primary/5 border border-primary/20'
              : 'bg-surface-container hover:bg-surface-container-high border border-outline-variant/50'
          } ${saving ? 'opacity-60' : ''}`}
        >
          {/* Drag handle (not for root) */}
          {!isRoot && (
            <span
              aria-label={`Drag ${node.name} to reorder`}
              className="cursor-grab text-on-surface-variant/60 hover:text-on-surface-variant select-none"
              aria-hidden="false"
            >
              ⠿
            </span>
          )}

          {/* Depth indicator */}
          {node.depth > 0 && (
            <span className="text-xs text-on-surface-variant/50" aria-hidden="true">
              {'└'.padStart(node.depth, ' ')}
            </span>
          )}

          {/* Node name and metadata */}
          <span className="flex-1 font-medium text-sm text-on-surface truncate">
            {node.name}
          </span>

          {/* Visibility badge */}
          <span
            className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${
              node.visibility === 'public'
                ? 'bg-success-container text-success'
                : node.visibility === 'pending_review'
                  ? 'bg-warning-container text-warning'
                  : 'bg-surface-container-high text-on-surface-variant'
            }`}
          >
            {node.visibility === 'pending_review'
              ? 'Review'
              : node.visibility}
          </span>

          {/* Published badge */}
          {node.isPublished && (
            <span className="inline-flex items-center rounded-full bg-primary/10 text-primary px-2 py-0.5 text-xs font-medium">
              Published
            </span>
          )}

          {/* Reorder buttons (keyboard accessible alternative to drag) */}
          {!isRoot && (
            <div className="flex gap-1">
              <button
                type="button"
                onClick={() => {
                  void handleReorderWithinParent(node.id, 'up');
                }}
                disabled={saving || siblingIndex === 0}
                aria-label={`Move ${node.name} up`}
                className="rounded p-1 text-xs text-on-surface-variant hover:bg-primary/10 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
              >
                ▲
              </button>
              <button
                type="button"
                onClick={() => {
                  void handleReorderWithinParent(node.id, 'down');
                }}
                disabled={saving || siblingIndex === siblingCount - 1}
                aria-label={`Move ${node.name} down`}
                className="rounded p-1 text-xs text-on-surface-variant hover:bg-primary/10 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
              >
                ▼
              </button>
            </div>
          )}
        </div>

        {/* Children */}
        {hasChildren && (
          <ul role="group" className="mt-1 space-y-1">
            {node.children
              .sort((a, b) => a.position - b.position)
              .map((child, idx) =>
                renderNode(
                  child,
                  false,
                  node.children.length,
                  idx,
                ),
              )}
          </ul>
        )}
      </li>
    );
  };

  // ── Main render ───────────────────────────────────────────────────────

  return (
    <div className="space-y-3">
      {/* Toast notifications */}
      {toasts.length > 0 && (
        <div className="space-y-2" aria-live="polite" aria-relevant="additions">
          {toasts.map((toast) => (
            <div
              key={toast.id}
              role="alert"
              className={`flex items-center justify-between rounded-lg px-4 py-2 text-sm ${
                toast.type === 'error'
                  ? 'bg-error-container text-on-error-container'
                  : 'bg-success-container text-success'
              }`}
            >
              <span>{toast.message}</span>
              <button
                type="button"
                onClick={() => dismissToast(toast.id)}
                aria-label="Dismiss notification"
                className="ml-3 shrink-0 rounded p-1 hover:bg-black/10 transition-colors"
              >
                ✕
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Tree */}
      {treeData.children.length === 0 && (
        <div
          className="flex min-h-[80px] items-center justify-center rounded-xl bg-surface-container p-6 text-center"
          role="status"
          aria-label="No sub-plans"
        >
          <p className="text-sm text-on-surface-variant">
            No sub-plans in this hierarchy.
          </p>
        </div>
      )}

      <ul role="tree" aria-label="Sub-plan hierarchy" className="space-y-1">
        {renderNode(treeData, true, 1, 0)}
      </ul>

      {saving && (
        <p className="text-xs text-on-surface-variant text-center" aria-live="polite">
          Saving changes...
        </p>
      )}
    </div>
  );
}
