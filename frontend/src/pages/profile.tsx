// frontend/src/pages/profile.tsx
import { useState, useEffect, useRef } from 'react';
import Head from 'next/head';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';
import { useAuth } from '@/context/auth-context';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { formatDate } from '@/utils/date';
import { useRouter } from 'next/router';
import Image from 'next/image';
import { User } from '@/types/user';

function Profile() {
  const { t } = useTranslation(['common', 'profile']);
  const router = useRouter();
  const { user, keycloak } = useAuth();
  const [showTokenInfo, setShowTokenInfo] = useState(false);
  const [tokenData, setTokenData] = useState<any>(null);
  const [uploadLoading, setUploadLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!user) {
      router.push('/login');
      return;
    }

    if (showTokenInfo && keycloak?.token) {
      const parts = keycloak.token.split('.');
      if (parts.length === 3) {
        try {
          const payload = JSON.parse(atob(parts[1]));
          setTokenData(payload);
        } catch (error) {
          console.error('Failed to parse token', error);
        }
      }
    }
  }, [user, showTokenInfo, keycloak, router]);

  if (!user) return null;

  // Generate user's initials for avatar
  const initials = `${user.givenName?.[0] || ''}${user.surname?.[0] || ''}`.toUpperCase();

  const handleAvatarUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    if (!event.target.files || event.target.files.length === 0) {
      return;
    }

    const file = event.target.files[0];
    
    // Validate file type
    if (!file.type.startsWith('image/')) {
      setError(t('profile.avatar.invalidType', { defaultValue: 'Only image files are allowed' }));
      return;
    }

    // Validate file size (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
      setError(t('profile.avatar.fileTooBig', { defaultValue: 'File exceeds 5MB size limit' }));
      return;
    }

    setUploadLoading(true);
    setError(null);

    try {
      const formData = new FormData();
      formData.append('avatar', file);

      const response = await fetch('/api/users/me/avatar', {
        method: 'POST',
        body: formData,
        headers: {
          'Authorization': `Bearer ${keycloak?.token || ''}`
        }
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || 'Failed to upload avatar');
      }

      const data = await response.json();
      
      // Force page refresh to show updated avatar
      router.reload();
    } catch (err: any) {
      setError(err.message || t('profile.avatar.uploadFailed', { defaultValue: 'Failed to upload avatar' }));
    } finally {
      setUploadLoading(false);
    }
  };

  const triggerFileInput = () => {
    if (fileInputRef.current) {
      fileInputRef.current.click();
    }
  };

  return (
    <>
      <Head>
        <title>{t('profile:title')} | DIVE</title>
      </Head>

      <main className="flex-1 p-6">
        <h1 className="text-2xl font-bold mb-6">{t('profile:title')}</h1>
        
        <div className="space-y-6">
          <Card className="bg-dive25-700">
            <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6">
              <div className="relative flex-shrink-0 w-24 h-24 rounded-full bg-white text-dive25-800 flex items-center justify-center text-3xl font-bold shadow-md border-4 border-white overflow-hidden">
                {user.avatar ? (
                  <Image 
                    src={user.avatar} 
                    alt={`${user.givenName} ${user.surname}`}
                    width={96}
                    height={96}
                    className="object-cover"
                  />
                ) : (
                  initials
                )}
                {uploadLoading && (
                  <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50">
                    <svg className="animate-spin h-8 w-8 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                  </div>
                )}
                <button 
                  onClick={triggerFileInput}
                  className="absolute bottom-0 right-0 bg-dive25-500 hover:bg-dive25-600 text-white rounded-full p-1 shadow-md" 
                  title={t('profile.avatar.change', { defaultValue: 'Change profile photo' })}
                >
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                </button>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  onChange={handleAvatarUpload}
                  className="hidden"
                />
              </div>
              <div className="flex-1 text-center sm:text-left">
                <h2 className="text-xl font-bold">{user.givenName} {user.surname}</h2>
                <p className="text-dive25-100">@{user.username}</p>
                <div className="mt-1">
                  {user.lastLogin && (
                    <p className="text-sm text-dive25-200">
                      {t('profile:lastLogin')}: {formatDate(user.lastLogin)}
                    </p>
                  )}
                </div>
                {error && (
                  <p className="mt-2 text-red-500 text-sm">
                    {error}
                  </p>
                )}
              </div>
              <div className="hidden md:block mt-4 sm:mt-0">
                <div className="flex flex-col items-center justify-center bg-dive25-600 px-4 py-3 rounded-md">
                  <span className="text-sm text-dive25-200">{t('profile:clearance')}</span>
                  <span className="text-lg font-bold">{user.clearance}</span>
                </div>
              </div>
            </div>
          </Card>

          {/* Personal Information */}
          <Card>
            <h2 className="font-bold text-xl mb-4">{t('profile:personalInformation')}</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <h3 className="text-sm font-medium text-dive25-400 mb-1">{t('profile:email')}</h3>
                <p>{user.email}</p>
              </div>
              <div>
                <h3 className="text-sm font-medium text-dive25-400 mb-1">{t('profile:organization')}</h3>
                <p>{user.organization || '-'}</p>
              </div>
              <div>
                <h3 className="text-sm font-medium text-dive25-400 mb-1">{t('profile:countryOfAffiliation')}</h3>
                <p>{user.countryOfAffiliation || '-'}</p>
              </div>
              <div className="md:hidden">
                <h3 className="text-sm font-medium text-dive25-400 mb-1">{t('profile:clearance')}</h3>
                <div className="flex items-center gap-2">
                  <span className="px-2 py-1 bg-dive25-700 text-white text-sm rounded">{user.clearance}</span>
                </div>
              </div>
            </div>
          </Card>

          {/* Security Information */}
          <Card>
            <h2 className="font-bold text-xl mb-4">{t('profile:securityInformation')}</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <h3 className="text-sm font-medium text-dive25-400 mb-1">{t('profile:roles')}</h3>
                <div className="flex flex-wrap gap-1">
                  {user.roles?.map((role, index) => (
                    <span key={index} className="px-2 py-1 bg-dive25-700 text-white text-sm rounded">
                      {role}
                    </span>
                  ))}
                </div>
              </div>
              {user.caveats && (
                <div>
                  <h3 className="text-sm font-medium text-dive25-400 mb-1">{t('profile:caveats')}</h3>
                  <div className="flex flex-wrap gap-1">
                    {user.caveats.map((caveat, index) => (
                      <span key={index} className="px-2 py-1 bg-dive25-700 text-white text-sm rounded">
                        {caveat}
                      </span>
                    ))}
                  </div>
                </div>
              )}
              {user.coi && (
                <div>
                  <h3 className="text-sm font-medium text-dive25-400 mb-1">{t('profile:coi')}</h3>
                  <div className="flex flex-wrap gap-1">
                    {user.coi.map((coi, index) => (
                      <span key={index} className="px-2 py-1 bg-dive25-700 text-white text-sm rounded">
                        {coi}
                      </span>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </Card>

          {/* Session Information */}
          <Card>
            <h2 className="font-bold text-xl mb-4">{t('profile:sessionInformation')}</h2>
            <div>
              <Button
                variant={showTokenInfo ? 'primary' : 'secondary'}
                onClick={() => setShowTokenInfo(!showTokenInfo)}
              >
                {showTokenInfo ? t('profile:hideToken', { defaultValue: 'Hide Token Info' }) : t('profile:showToken', { defaultValue: 'Show Token Info' })}
              </Button>

              {showTokenInfo && tokenData && (
                <div className="mt-4">
                  <h3 className="text-sm font-medium text-dive25-400 mb-1">{t('profile:tokenInformation')}</h3>
                  <div className="bg-dive25-900 p-4 rounded-md mt-2 overflow-x-auto">
                    <pre className="text-sm text-dive25-100">{JSON.stringify(tokenData, null, 2)}</pre>
                  </div>
                </div>
              )}
            </div>
          </Card>
        </div>
      </main>
    </>
  );
}

export const getServerSideProps = async ({ locale }: { locale: string }) => {
  return {
    props: {
      ...(await serverSideTranslations(locale, ['common', 'profile'])),
    },
  };
};

export default Profile;