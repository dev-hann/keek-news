/** Why saving a picture or a video, or sharing it, did not happen. As the Flutter app names them. */
export type MediaSaveFailureType =
  'network' | 'permission' | 'canceled' | 'inProgress' | 'unexpected';

/** `detail` says more about a network failure, when the plugin could. */
export interface MediaSaveFailure {
  type: MediaSaveFailureType;
  detail?: string;
}

/** How a save or a share ended. */
export type MediaSaveResult = { ok: true } | { ok: false; failure: MediaSaveFailure };
