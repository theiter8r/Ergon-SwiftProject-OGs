import { App, getApp, getApps, initializeApp } from "firebase-admin/app";

export const getAdminApp = (): App => {
  if (getApps().length > 0) {
    return getApp();
  }

  return initializeApp();
};
