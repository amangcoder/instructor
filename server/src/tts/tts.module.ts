import { Module } from '@nestjs/common';
import { TtsController } from './tts.controller';
import { TtsService } from './tts.service';
import { TtsEnumerationService } from './tts-enumeration.service';
import { TtsPregenService } from './tts-pregen.service';
import { TtsBatchPregenService } from './tts-batch-pregen.service';
import { ProviderRegistryService } from './providers/provider-registry.service';
import { KokoroProxyService } from './providers/kokoro-proxy.service';
import { ElevenLabsProxyService } from './providers/elevenlabs-proxy.service';
import { VibeVoiceProxyService } from './providers/vibevoice-proxy.service';
import { AuthModule } from '../auth/auth.module';
import { DatabaseModule } from '../database/database.module';
import { PlanVoicesRepository } from '../database/repositories/plan-voices.repository';
import { VoiceRepository } from '../database/repositories/voice.repository';

@Module({
  imports: [AuthModule, DatabaseModule],
  controllers: [TtsController],
  providers: [
    TtsService,
    TtsEnumerationService,
    TtsPregenService,
    TtsBatchPregenService,
    ProviderRegistryService,
    KokoroProxyService,
    ElevenLabsProxyService,
    VibeVoiceProxyService,
    // Registered explicitly so TtsBatchPregenService can inject it as @Optional().
    // DatabaseModule is @Global() and already provides this; listing it here makes
    // the dependency visible at the module boundary and supports isolated testing.
    PlanVoicesRepository,
    VoiceRepository,
  ],
  exports: [TtsService, TtsPregenService, TtsBatchPregenService, ProviderRegistryService],
})
export class TtsModule {}
