// frontend/src/components/security/SecurityBanner.tsx
import { useTranslation } from 'next-i18next';

interface SecurityBannerProps {
  classification?: string;
  caveats?: string[];
}

export function SecurityBanner({ classification = 'UNCLASSIFIED', caveats = [] }: SecurityBannerProps) {
  const { t } = useTranslation('common');
  
  // Determine banner color based on classification
  const getBannerColor = (classification: string) => {
    switch (classification?.toUpperCase()) {
      case 'TOP SECRET':
      case 'COSMIC TOP SECRET':
      case 'EU TOP SECRET':
        return 'bg-classification-top-secret';
      case 'SECRET':
      case 'NATO SECRET':
      case 'EU SECRET':
        return 'bg-classification-secret';
      case 'CONFIDENTIAL':
      case 'NATO CONFIDENTIAL':
      case 'EU CONFIDENTIAL':
        return 'bg-classification-confidential';
      case 'RESTRICTED':
        return 'bg-classification-restricted';
      case 'UNCLASSIFIED':
      default:
        return 'bg-classification-unclassified';
    }
  };
  
  // Format classification display
  const formatClassification = (classification: string) => {
    return classification.toUpperCase();
  };

  const bannerColor = getBannerColor(classification);
  
  return (
    <div className={`${bannerColor} text-white text-center py-1 px-4 sticky top-0 z-50`}>
      <div className="flex flex-col sm:flex-row justify-center items-center text-sm font-bold">
        <span>{t('security.classification')}: {formatClassification(classification)}</span>
        
        {caveats && caveats.length > 0 && (
          <span className="sm:ml-4 mt-1 sm:mt-0">
            {caveats.join(' // ')}
          </span>
        )}
      </div>
    </div>
  );
}