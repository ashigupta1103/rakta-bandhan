/**
 * AuthContext — Global admin authentication state.
 *
 * Admin-ness is NOT a custom claim (setting those needs the Admin SDK /
 * Cloud Functions, which Spark can't deploy) — it's the same check the
 * Flutter app uses: does an `admins/{uid}` Firestore doc exist for this
 * user? (see firestore.rules' isAdmin() and Backend.isCurrentUserAdmin()
 * in lib/services/backend.dart). Sign in with the same admin account
 * that's already bootstrapped for the phone app.
 *
 * Provides:
 *  - currentUser: Firebase User object (or null)
 *  - isAdmin: boolean (verified via admins/{uid} doc existence)
 *  - loading: boolean
 *  - login(email, password): Promise
 *  - logout(): Promise
 */

import React, { createContext, useContext, useEffect, useState } from 'react';
import {
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
  type User,
} from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../lib/firebase';

async function checkIsAdmin(uid: string): Promise<boolean> {
  const snap = await getDoc(doc(db, 'admins', uid));
  return snap.exists();
}

interface AuthContextType {
  currentUser: User | null;
  isAdmin: boolean;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      setCurrentUser(user);
      if (user) {
        setIsAdmin(await checkIsAdmin(user.uid));
      } else {
        setIsAdmin(false);
      }
      setLoading(false);
    });

    return unsubscribe;
  }, []);

  async function login(email: string, password: string) {
    const cred = await signInWithEmailAndPassword(auth, email, password);
    if (!(await checkIsAdmin(cred.user.uid))) {
      await signOut(auth);
      throw new Error('Access denied. This account does not have admin privileges.');
    }
  }

  async function logout() {
    await signOut(auth);
  }

  const value: AuthContextType = {
    currentUser,
    isAdmin,
    loading,
    login,
    logout,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
