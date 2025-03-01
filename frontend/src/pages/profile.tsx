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

  return (
    <>
      <Head>
        <title>{t('profile:title')} | DIVE25</title>
      </Head>

      <SecurityBanner />

      <div className="px-4 sm:px-6 lg:px-8 py-6">
        <h1 className="text-2xl font-bold text-gray-900 mb-6">
          {t('profile:title')}
        </h1>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <Card>
              <div className="px-4 py-5 sm:px-6">
                <h3 className="text-lg font-medium leading-6 text-gray-900">
                  {t('profile:personalInformation')}
                </h3>
              </div>
              <div className="border-t border-gray-200">
                <dl>
                  <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">
                      {t('profile:fullName')}
                    </dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                      {user.givenName} {user.surname}
                    </dd>
                  </div>
                  <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">
                      {t('profile:username')}
                    </dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                      {user.username}
                    </dd>
                  </div>
                  <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">
                      {t('profile:email')}
                    </dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                      {user.email}
                    </dd>
                  </div>
                  <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">
                      {t('profile:organization')}
                    </dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                      {user.organization}
                    </dd>
                  </div>
                  <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">
                      {t('profile:country')}
                    </dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                      {user.countryOfAffiliation}
                    </dd>
                  </div>
                  <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">
                      {t('profile:clearance')}
                    </dt>
                    <dd className="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                      <Badge variant="clearance" level={user.clearance}>
                        {user.clearance}
                      </Badge>
                    </dd>
                  </div>
                  <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">
                      {t('profile:caveats')}
                    </dt>
                    <dd className="mt-1 text-sm flex flex-wrap gap-2 sm:col-span-2 sm:mt-0">
                      {user.caveats?.length ? (
                        user.caveats.map((caveat) => (
                          <Badge key={caveat} variant="secondary">
                            {caveat}
                          </Badge>
                        ))
                      ) : (
                        <span className="text-gray-500">—</span>
                      )}
                    </dd>
                  </div>
                  <div className="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">
                      {t('profile:communities')}
                    </dt>
                    <dd className="mt-1 text-sm flex flex-wrap gap-2 sm:col-span-2 sm:mt-0">
                      {user.coi?.length ? (
                        user.coi.map((coi) => (
                          <Badge key={coi} variant="tertiary">
                            {coi}
                          </Badge>
                        ))
                      ) : (
                        <span className="text-gray-500">—</span>
                      )}
                    </dd>
                  </div>
                  <div className="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                    <dt className="text-sm font-medium text-gray-500">
                      {t('profile:roles')}
                    </dt>
                    <dd className="mt-1 text-sm flex flex-wrap gap-2 sm:col-span-2 sm:mt-0">
                      {user.roles?.length ? (
                        user.roles.map((role) => (
                          <Badge key={role} variant="info">
                            {role}
                          </Badge>
                        ))
                      ) : (
                        <span className="text-gray-500">—</span>
                      )}
                    </dd>
                  </div>
                </dl>
              </div>
            </Card>
          </div>

          <div>
            <Card>
              <div className="px-4 py-5 sm:px-6">
                <h3 className="text-lg font-medium leading-6 text-gray-900">
                  {t('profile:sessionInformation')}
                </h3>
              </div>
              <div className="border-t border-gray-200 px-4 py-5">
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-500">
                      {t('profile:lastLogin')}
                    </label>
                    <div className="mt-1 text-sm text-gray-900">
                      {user.lastLogin ? formatDate(new Date(user.lastLogin)) : '—'}
                    </div>
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-gray-500">
                      {t('profile:sessionStatus')}
                    </label>
                    <div className="mt-1">
                      <Badge variant="success">
                        {t('profile:active')}
                      </Badge>
                    </div>
                  </div>

                  <div className="pt-4">
                    <Button
                      onClick={() => setShowTokenInfo(!showTokenInfo)}
                      variant="secondary"
                      size="sm"
                      className="w-full"
                    >
                      {showTokenInfo 
                        ? t('profile:hideTokenInfo') 
                        : t('profile:showTokenInfo')}
                    </Button>

                    {showTokenInfo && (
                      <div className="mt-4 text-xs">
                        <div className="bg-gray-100 p-3 rounded overflow-auto max-h-64">
                          <pre>{JSON.stringify(user, null, 2)}</pre>
                        </div>
                        <p className="mt-2 text-gray-500 text-xs">
                          {t('profile:tokenInfoWarning')}
                        </p>
                      </div>
                    )}
                  </div>
                </div>
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