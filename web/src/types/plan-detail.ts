/**
 * Plan Detail — types for the admin plan detail page.
 *
 * These mirror the backend DTOs from PlansModuleExtension and PlanVoicesModule.
 */

// ---------------------------------------------------------------------------
// Plan Tree (recursive sub-plan hierarchy)
// ---------------------------------------------------------------------------

export interface PlanTreeNode {
  id: string;
  name: string;
  parentPlanId: string | null;
  position: number;
  visibility: string;
  isPublished: boolean;
  depth: number;
  children: PlanTreeNode[];
}

// ---------------------------------------------------------------------------
// Voice (registry row — populates admin voice-selector dropdowns)
// ---------------------------------------------------------------------------

export interface Voice {
  id: string;
  slug: string;
  displayName: string;
  locale: string;
  provider: string;
  sampleUrl: string | null;
  isPublished: boolean;
  createdAt: string;
  updatedAt: string;
}

// ---------------------------------------------------------------------------
// Plan Voice (per-voice TTS status)
// ---------------------------------------------------------------------------

export type PlanVoiceStatus = 'pending' | 'processing' | 'ready' | 'failed';

export interface PlanVoice {
  id: string;
  planId: string;
  voiceId: string;
  locale: string;
  status: PlanVoiceStatus;
  audioUrl: string | null;
  durationMs: number | null;
  errorMsg: string | null;
  generatedAt: string | null;
  voice?: {
    displayName: string;
    slug: string;
  };
}

// ---------------------------------------------------------------------------
// Plan Detail (full plan record for admin)
// ---------------------------------------------------------------------------

export type PlanVisibility = 'private' | 'pending_review' | 'public';

// ---------------------------------------------------------------------------
// Plan Step (parsed from planJson)
//
// Discriminator is `runtimeType` (Freezed sealed class convention).
// Durations are serialized as microseconds (Dart Duration default).
// ---------------------------------------------------------------------------

export interface PlanStepBase {
  runtimeType: string;
  id: string;
}
export interface PlanStepSay extends PlanStepBase {
  runtimeType: 'say';
  text: string;
  voiceId?: string | null;
  /** Microseconds, optional. */
  estimatedDuration?: number | null;
}
export interface PlanStepWait extends PlanStepBase {
  runtimeType: 'wait';
  /** Microseconds. */
  duration: number;
}
export interface PlanStepNotify extends PlanStepBase {
  runtimeType: 'notify';
  title: string;
  body: string;
}
export interface PlanStepPlay extends PlanStepBase {
  runtimeType: 'play';
  audioAssetKey: string;
  loop?: boolean;
  volume?: number;
  fadeInMs?: number | null;
  fadeOutMs?: number | null;
}
export interface PlanStepStopAudio extends PlanStepBase {
  runtimeType: 'stopAudio';
}
export interface PlanStepRepeat extends PlanStepBase {
  runtimeType: 'repeat';
  count: number;
  children: PlanStep[];
}
export interface PlanStepCount extends PlanStepBase {
  runtimeType: 'count';
  from: number;
  to: number;
  intervalSeconds: number;
}

export type PlanStep =
  | PlanStepSay
  | PlanStepWait
  | PlanStepNotify
  | PlanStepPlay
  | PlanStepStopAudio
  | PlanStepRepeat
  | PlanStepCount;

export interface ParsedPlanJson {
  id?: string;
  name?: string;
  description?: string | null;
  category?: string;
  tags?: string[];
  defaultVoice?: string;
  steps: PlanStep[];
}

export interface PlanDetail {
  id: string;
  name: string;
  description: string | null;
  parentPlanId: string | null;
  position: number;
  visibility: PlanVisibility;
  isPublished: boolean;
  ownerUserId: string | null;
  ttsStatus: string | null;
  ttsTotal: number;
  ttsCompleted: number;
  planJson: string;
  createdAt: string;
  updatedAt: string;
}
