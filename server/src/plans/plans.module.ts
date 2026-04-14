import { Module } from '@nestjs/common';
import { PlansController } from './plans.controller';
import { PlansService } from './plans.service';
import { AuthModule } from '../auth/auth.module';
import { TtsModule } from '../tts/tts.module';

@Module({
  imports: [AuthModule, TtsModule],
  controllers: [PlansController],
  providers: [PlansService],
})
export class PlansModule {}
