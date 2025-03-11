// frontend/src/pages/profile.tsx
import { useState } from 'react';
import Head from 'next/head';
import { useTranslation } from 'next-i18next';
import { serverSideTranslations } from 'next-i18next/serverSideTranslations';
import { GetServerSideProps } from 'next';
import { withAuth } from '@/components/hoc/withAuth';
import { SecurityBanner } from '@/components/security/SecurityBanner';
import { useAuth } from '@/context/auth-context';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { formatDate } from '@/utils/date';

function Profile() {
  const { t } = useTranslation(['common', 'profile']);
  const { user } = useAuth();
  const [showTokenInfo, setShowTokenInfo] = useState(false);

  if (!user) {
    return null;
  }

  // Generate user's initials for avatar
  const initials = `${user.givenName?.[0] || ''}${user.surname?.[0] || ''}`.toUpperCase();

  return (
    <>
      <Head>
        <title>{t('profile:title')} | DIVE25</title>
      </Head>

      <SecurityBanner />

      <div className="px-4 sm:px-6 lg:px-8 py-8 max-w-7xl mx-auto">
        {/* Profile Header */}
        <div className="bg-gradient-to-r from-dive25-600 to-dive25-800 rounded-xl shadow-lg p-6 mb-8 text-white">
          <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6">
            <div className="flex-shrink-0 w-24 h-24 rounded-full bg-white text-dive25-800 flex items-center justify-center text-3xl font-bold shadow-md border-4 border-white">
              {initials}
            </div>
            <div className="flex-1 text-center sm:text-left">
              <h1 className="text-3xl font-bold">
                {user.givenName} {user.surname}
              </h1>
              <p className="text-dive25-100 text-lg mt-1">@{user.username}</p>
              <div className="mt-2 flex flex-wrap gap-2 justify-center sm:justify-start">
                <Badge 
                  variant="clearance" 
                  level={user.clearance}
                  className="border border-white/30 backdrop-blur-sm bg-opacity-70"
                >
                  {user.clearance}
                </Badge>
                {user.roles && user.roles.length > 0 && (
                  <Badge 
                    variant="info"
                    className="border border-white/30 backdrop-blur-sm bg-opacity-70"
                  >
                    {user.roles[0]}
                    {user.roles.length > 1 && `+${user.roles.length - 1}`}
                  </Badge>
                )}
              </div>
            </div>
            <div className="hidden md:block mt-4 sm:mt-0">
              <div className="flex items-center gap-2 text-sm text-dive25-100">
                <span>
                  {t('profile:lastLogin')}: {user.lastLogin ? formatDate(new Date(user.lastLogin)) : '—'}
                </span>
                <span className="px-1.5 py-0.5 rounded-full bg-green-500/20 text-green-300 border border-green-400/30 flex items-center gap-1 text-xs">
                  <span className="w-2 h-2 rounded-full bg-green-400 animate-pulse"></span>
                  {t('profile:active')}
                </span>
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Main Information */}
          <div className="lg:col-span-2 space-y-8">
            {/* Personal Information Card */}
            <Card className="overflow-hidden transition-all duration-200 hover:shadow-md">
              <div className="px-6 py-5 flex justify-between items-center border-b border-gray-200 bg-gray-50">
                <h3 className="text-lg font-semibold text-gray-900">
                  {t('profile:personalInformation')}
                </h3>
                <Badge variant="primary" className="bg-opacity-70">
                  {t('profile:userDetails')}
                </Badge>
              </div>
              <div className="divide-y divide-gray-200">
                <div className="grid grid-cols-1 sm:grid-cols-2 divide-y sm:divide-y-0 sm:divide-x divide-gray-200">
                  <div className="p-5">
                    <h4 className="font-medium text-sm text-gray-500 mb-1">
                      {t('profile:email')}
                    </h4>
                    <p className="text-gray-900">{user.email}</p>
                  </div>
                  <div className="p-5">
                    <h4 className="font-medium text-sm text-gray-500 mb-1">
                      {t('profile:organization')}
                    </h4>
                    <p className="text-gray-900">{user.organization || '—'}</p>
                  </div>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 divide-y sm:divide-y-0 sm:divide-x divide-gray-200">
                  <div className="p-5">
                    <h4 className="font-medium text-sm text-gray-500 mb-1">
                      {t('profile:username')}
                    </h4>
                    <p className="text-gray-900">{user.username}</p>
                  </div>
                  <div className="p-5">
                    <h4 className="font-medium text-sm text-gray-500 mb-1">
                      {t('profile:country')}
                    </h4>
                    <p className="text-gray-900">{user.countryOfAffiliation || '—'}</p>
                  </div>
                </div>
              </div>
            </Card>

            {/* Security Clearance Card */}
            <Card className="overflow-hidden transition-all duration-200 hover:shadow-md">
              <div className="px-6 py-5 flex justify-between items-center border-b border-gray-200 bg-gray-50">
                <h3 className="text-lg font-semibold text-gray-900">
                  {t('profile:securityInformation')}
                </h3>
                <Badge variant="warning" className="bg-opacity-70">
                  {t('profile:restrictedAccess')}
                </Badge>
              </div>
              
              <div className="p-5 space-y-6">
                <div>
                  <h4 className="font-medium text-sm text-gray-500 mb-3">
                    {t('profile:clearance')}
                  </h4>
                  <Badge 
                    variant="clearance" 
                    level={user.clearance}
                    className="text-sm px-3 py-1"
                  >
                    {user.clearance}
                  </Badge>
                </div>
                
                <div>
                  <h4 className="font-medium text-sm text-gray-500 mb-3">
                    {t('profile:caveats')}
                  </h4>
                  <div className="flex flex-wrap gap-2">
                    {user.caveats?.length ? (
                      user.caveats.map((caveat) => (
                        <Badge 
                          key={caveat} 
                          variant="secondary"
                          className="transition-all duration-200 hover:bg-gray-200"
                        >
                          {caveat}
                        </Badge>
                      ))
                    ) : (
                      <span className="text-gray-500 text-sm italic">{t('profile:noCaveatsAssigned')}</span>
                    )}
                  </div>
                </div>
                
                <div>
                  <h4 className="font-medium text-sm text-gray-500 mb-3">
                    {t('profile:communities')}
                  </h4>
                  <div className="flex flex-wrap gap-2">
                    {user.coi?.length ? (
                      user.coi.map((coi) => (
                        <Badge 
                          key={coi} 
                          variant="tertiary"
                          className="transition-all duration-200 hover:bg-indigo-200"
                        >
                          {coi}
                        </Badge>
                      ))
                    ) : (
                      <span className="text-gray-500 text-sm italic">{t('profile:noCommunitiesAssigned')}</span>
                    )}
                  </div>
                </div>
              </div>
            </Card>
          </div>

          {/* Sidebar */}
          <div className="space-y-8">
            {/* Session Card */}
            <Card className="overflow-hidden transition-all duration-200 hover:shadow-md">
              <div className="px-6 py-5 border-b border-gray-200 bg-gray-50">
                <h3 className="text-lg font-semibold text-gray-900">
                  {t('profile:sessionInformation')}
                </h3>
              </div>
              <div className="p-5 space-y-4">
                <div>
                  <h4 className="font-medium text-sm text-gray-500 mb-1">
                    {t('profile:lastLogin')}
                  </h4>
                  <p className="text-gray-900">
                    {user.lastLogin ? formatDate(new Date(user.lastLogin)) : '—'}
                  </p>
                </div>
                
                <div>
                  <h4 className="font-medium text-sm text-gray-500 mb-1">
                    {t('profile:sessionStatus')}
                  </h4>
                  <div className="flex items-center gap-2 mt-1">
                    <span className="w-3 h-3 rounded-full bg-green-500 animate-pulse"></span>
                    <span className="text-green-700 font-medium">{t('profile:active')}</span>
                  </div>
                </div>
              </div>
            </Card>

            {/* Roles Card */}
            <Card className="overflow-hidden transition-all duration-200 hover:shadow-md">
              <div className="px-6 py-5 border-b border-gray-200 bg-gray-50">
                <h3 className="text-lg font-semibold text-gray-900">
                  {t('profile:roles')}
                </h3>
              </div>
              <div className="p-5">
                <div className="flex flex-wrap gap-2">
                  {user.roles?.length ? (
                    user.roles.map((role) => (
                      <Badge 
                        key={role} 
                        variant="info"
                        className="transition-all duration-200 hover:bg-blue-200 px-3 py-1"
                      >
                        {role}
                      </Badge>
                    ))
                  ) : (
                    <span className="text-gray-500 text-sm italic">{t('profile:noRolesAssigned')}</span>
                  )}
                </div>
              </div>
            </Card>

            {/* Developer Card */}
            <Card className="overflow-hidden transition-all duration-200 hover:shadow-md">
              <div className="px-6 py-5 border-b border-gray-200 bg-gray-50">
                <h3 className="text-lg font-semibold text-gray-900">
                  {t('profile:developerTools')}
                </h3>
              </div>
              <div className="p-5">
                <Button
                  onClick={() => setShowTokenInfo(!showTokenInfo)}
                  variant="secondary"
                  size="sm"
                  className="w-full transition-all duration-200 hover:bg-gray-100"
                >
                  {showTokenInfo 
                    ? t('profile:hideTokenInfo') 
                    : t('profile:showTokenInfo')}
                </Button>

                {showTokenInfo && (
                  <div className="mt-4 text-xs">
                    <div className="bg-gray-100 p-3 rounded-md overflow-auto max-h-64 border border-gray-200">
                      <pre>{JSON.stringify(user, null, 2)}</pre>
                    </div>
                    <p className="mt-2 text-gray-500 text-xs">
                      {t('profile:tokenInfoWarning')}
                    </p>
                  </div>
                )}
              </div>
            </Card>
          </div>
        </div>
      </div>
    </>
  );
}

export const getServerSideProps: GetServerSideProps = async ({ locale }) => {
  return {
    props: {
      ...(await serverSideTranslations(locale || 'en', ['common', 'profile'])),
    },
  };
};

export default withAuth(Profile);