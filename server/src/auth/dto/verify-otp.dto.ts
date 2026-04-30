import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, Length, Matches } from 'class-validator';

export class VerifyOtpDto {
  @ApiProperty({
    description: 'Email address that the OTP was sent to',
    example: 'user@example.com',
    format: 'email',
  })
  @IsEmail({}, { message: 'email must be a valid email address' })
  @IsNotEmpty()
  email!: string;

  @ApiProperty({
    description: 'Six-digit one-time password sent to the email address',
    example: '123456',
    minLength: 6,
    maxLength: 6,
    pattern: '^\\d{6}$',
  })
  @IsString()
  @IsNotEmpty()
  @Length(6, 6, { message: 'OTP must be exactly 6 digits' })
  @Matches(/^\d{6}$/, { message: 'OTP must contain only digits' })
  otp!: string;
}
