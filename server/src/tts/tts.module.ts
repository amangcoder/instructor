import { Module } from '@nestjs/common';
import { TtsController } from './tts.controller';
import { TtsService } from './tts.service';
import { TtsEnumerationService } from './tts-enumeration.service';
import { TtsPregenService } from './tts-pregen.service';
import { ProviderRegistryService } from './providers/provider-registry.service';
import { KokoroProxyService } from './providers/kokoro-proxy.service';
import { ElevenLabsProxyService } from './providers/elevenlabs-proxy.service';
import { AuthModule } from '../auth/auth.module';
import { DatabaseModule } from '../database/database.module';

@Module({
  imports: [AuthModule, DatabaseModule],
  controllers: [TtsController],
  providers: [TtsService, TtsEnumerationService, TtsPregenService, ProviderRegistryService, KokoroProxyService, ElevenLabsProxyService],
  exports: [TtsService, TtsPregenService, ProviderRegistryService],
})
export class TtsModule {}
