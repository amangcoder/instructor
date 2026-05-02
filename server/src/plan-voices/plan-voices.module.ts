import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { TtsModule } from '../tts/tts.module';
import { PlanVoicesController } from './plan-voices.controller';
import { PlanVoicesService } from './plan-voices.service';

/**
 * PlanVoicesModule — admin endpoints for per-voice TTS management.
 *
 * Public surface:
 *   POST /api/admin/plans/:id/voices/:voiceId/regenerate
 *     Queue TTS synthesis for a failed or pending plan_voice rendition.
 *   GET /api/admin/plan-voices?status=failed
 *     List paginated plan_voice rows filtered by status.
 *
 * Dependencies:
 *   - TtsModule provides TtsBatchPregenService
 *   - DatabaseModule (global) provides PlanVoicesRepository and VoiceRepository
 *
 * Visibility gate contract (REQ-028):
 *   A plan is visible to end-users only when:
 *     1. plans.is_published = true
 *     2. plans.visibility = 'public'
 *     3. EXISTS (SELECT 1 FROM plan_voices WHERE plan_id = ? AND status = 'ready')
 */
@Module({
  imports: [AuthModule, TtsModule],
  controllers: [PlanVoicesController],
  providers: [PlanVoicesService],
  exports: [PlanVoicesService],
})
export class PlanVoicesModule {}
