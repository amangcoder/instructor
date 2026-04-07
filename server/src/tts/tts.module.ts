import { Module } from '@nestjs/common';
import { TtsController } from './tts.controller';
import { TtsService } from './tts.service';
import { ProviderRegistryService } from './providers/provider-registry.service';
import { KokoroProxyService } from './providers/kokoro-proxy.service';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [AuthModule],
  controllers: [TtsController],
  providers: [TtsService, ProviderRegistryService, KokoroProxyService],
  exports: [TtsService, ProviderRegistryService],
})
export class TtsModule {}
