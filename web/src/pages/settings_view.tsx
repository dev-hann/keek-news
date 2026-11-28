import { useEffect } from 'react';
import { Bookmark, Code, ImageOff } from 'lucide-react';
import { Switch } from '../components/ui/switch';
import { registeredCommunities } from '../model/community';
import { useBlockedImages } from '../provider/blocked_images_provider';
import { updateNotifier, useUpdate } from '../provider/update_provider';
import { settingsNotifier, useSettings } from '../provider/settings_provider';
import { AppBar } from '../widgets/app_bar';
import { SettingsGroup } from '../widgets/settings_group';
import { SettingsTile } from '../widgets/settings_tile';
import { UpdateRow } from '../widgets/update_row';

const REPO_URL = 'https://github.com/dev-hann/keek-news';

interface SettingsViewProps {
  onBack: () => void;
  onOpenBookmarks: () => void;
  onOpenBlockedImages: () => void;
}

export function SettingsView({ onBack, onOpenBookmarks, onOpenBlockedImages }: SettingsViewProps) {
  const enabled = useSettings();
  const settings = settingsNotifier();
  const images = useBlockedImages();
  const update = useUpdate();
  const updater = updateNotifier();

  // A new version is looked for each time the settings open.
  useEffect(() => {
    updater.enter();
  }, [updater]);

  return (
    <>
      <AppBar title="설정" onBack={onBack} />
      <main className="pb-8">
        <SettingsGroup title="커뮤니티">
          {registeredCommunities.map((community) => {
            const canDisable = settings.canDisable(community.id);
            return (
              <SettingsTile
                key={community.id}
                title={community.displayName}
                leading={
                  <span
                    className="flex size-7 items-center justify-center rounded-full text-xs font-semibold"
                    style={{
                      backgroundColor: `color-mix(in oklab, ${community.brandColor} 15%, transparent)`,
                      color: community.brandColor,
                    }}
                  >
                    {community.shortName}
                  </span>
                }
                trailing={
                  <Switch
                    checked={enabled.has(community.id)}
                    disabled={!canDisable}
                    onCheckedChange={() => settings.toggle(community.id)}
                    aria-label={`${community.displayName} 보기`}
                    title={canDisable ? undefined : '켜진 커뮤니티가 하나뿐이라 끌 수 없습니다'}
                  />
                }
              />
            );
          })}
        </SettingsGroup>

        <SettingsGroup title="저장함">
          <SettingsTile
            title="저장한 게시물"
            leading={<Bookmark className="size-5" />}
            onClick={onOpenBookmarks}
          />
        </SettingsGroup>

        <SettingsGroup title="미디어 & 데이터">
          <SettingsTile
            title="차단된 이미지"
            subtitle={`${images.length}개`}
            leading={<ImageOff className="size-5" />}
            onClick={onOpenBlockedImages}
          />
        </SettingsGroup>

        <SettingsGroup title="정보">
          <UpdateRow
            state={update}
            onDownload={() => updater.download()}
            onCancel={() => updater.cancel()}
            onRetry={() => updater.retry()}
            onInstall={() => void updater.install()}
            onOpenInstallSettings={() => void updater.openInstallSettings()}
          />
          <SettingsTile
            title="소스 코드"
            subtitle="GitHub"
            href={REPO_URL}
            leading={<Code className="size-5" />}
          />
        </SettingsGroup>
      </main>
    </>
  );
}
