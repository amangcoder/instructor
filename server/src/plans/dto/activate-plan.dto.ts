import { IsIn, IsNotEmpty, IsString } from 'class-validator';

export class ActivatePlanDto {
  @IsString()
  @IsNotEmpty()
  planId!: string;

  @IsString()
  @IsIn(['standard', 'studio'])
  voiceQuality!: string;
}
