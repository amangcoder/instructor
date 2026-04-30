import { Module } from '@nestjs/common';
import { TtsController } from './tts.controller';
import { TtsService } from './tts.service';
import { TtsEnumerationService } from './tts-enumeration.service';
import { TtsPregenService } from './tts-pregen.service';
import { TtsBatchPregenService } from './tts-batch-pregen.service';
import { TtsAlignmentService } from './tts-alignment.service';
import { ProviderRegistryService } from './providers/provider-registry.service';
import { KokoroProxyService } from './providers/kokoro-proxy.service';
import { ElevenLabsProxyService } from './providers/elevenlabs-proxy.service';
import { AuthModule } from '../auth/auth.module';
import { DatabaseModule } from '../database/database.module';

@Module({
  imports: [AuthModule, DatabaseModule],
  controllers: [TtsController],
  providers: [TtsService, TtsEnumerationService, TtsPregenService, TtsBatchPregenService, TtsAlignmentService, ProviderRegistryService, KokoroProxyService, ElevenLabsProxyService],
  exports: [TtsService, TtsPregenService, TtsBatchPregenService, ProviderRegistryService],
})
export class TtsModule {}
