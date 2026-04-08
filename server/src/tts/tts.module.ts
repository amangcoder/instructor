import { Module } from '@nestjs/common';
import { TtsController } from './tts.controller';
import { TtsService } from './tts.service';
import { ProviderRegistryService } from './providers/provider-registry.service';
import { KokoroProxyService } from './providers/kokoro-proxy.service';
import { ElevenLabsProxyService } from './providers/elevenlabs-proxy.service';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [AuthModule],
  controllers: [TtsController],
  providers: [TtsService, ProviderRegistryService, KokoroProxyService, ElevenLabsProxyService],
  exports: [TtsService, ProviderRegistryService],
})
export class TtsModule {}
