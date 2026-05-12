import { requireNativeModule } from 'expo-modules-core';

interface HapticsAdvancedInterface {
  triggerCustomPattern(intensity: number): void;
  triggerSelection(): void;
  triggerNotification(type: 'success' | 'warning' | 'error'): void;
}

const HapticsAdvanced =
  requireNativeModule<HapticsAdvancedInterface>('HapticsAdvanced');

export function triggerCustomPattern(intensity: number): void {
  return HapticsAdvanced.triggerCustomPattern(intensity);
}

export function triggerSelection(): void {
  return HapticsAdvanced.triggerSelection();
}

export function triggerNotification(
  type: 'success' | 'warning' | 'error'
): void {
  return HapticsAdvanced.triggerNotification(type);
}
