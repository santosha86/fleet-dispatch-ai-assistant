import React, { useState, useEffect, FormEvent } from 'react';
import { apiFetch } from '../apiClient';

interface MfaSetupProps {
  onClose: () => void;
}

type Step = 'loading' | 'disabled' | 'qr' | 'enabled' | 'disable-confirm';

const MfaSetup: React.FC<MfaSetupProps> = ({ onClose }) => {
  const [step, setStep] = useState<Step>('loading');
  const [qrCode, setQrCode] = useState('');
  const [secret, setSecret] = useState('');
  const [verifyCode, setVerifyCode] = useState('');
  const [disablePassword, setDisablePassword] = useState('');
  const [disableCode, setDisableCode] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [successMsg, setSuccessMsg] = useState('');

  useEffect(() => {
    checkStatus();
  }, []);

  const checkStatus = async () => {
    try {
      const res = await apiFetch('/api/mfa/status', { method: 'POST' });
      const data = await res.json();
      setStep(data.mfa_enabled ? 'enabled' : 'disabled');
    } catch {
      setError('Could not check MFA status');
      setStep('disabled');
    }
  };

  const handleSetup = async () => {
    setLoading(true);
    setError('');
    try {
      const res = await apiFetch('/api/mfa/setup', { method: 'POST' });
      if (res.ok) {
        const data = await res.json();
        setQrCode(data.qr_code);
        setSecret(data.secret);
        setStep('qr');
      } else {
        const err = await res.json();
        setError(err.detail || 'Setup failed');
      }
    } catch {
      setError('Could not start MFA setup');
    } finally {
      setLoading(false);
    }
  };

  const handleVerify = async (e: FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const res = await apiFetch('/api/mfa/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code: verifyCode }),
      });
      if (res.ok) {
        setSuccessMsg('Two-factor authentication enabled successfully!');
        setStep('enabled');
        setVerifyCode('');
      } else {
        const err = await res.json();
        setError(err.detail || 'Invalid code');
      }
    } catch {
      setError('Verification failed');
    } finally {
      setLoading(false);
    }
  };

  const handleDisable = async (e: FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const res = await apiFetch('/api/mfa/disable', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password: disablePassword, totp_code: disableCode }),
      });
      if (res.ok) {
        setSuccessMsg('Two-factor authentication disabled.');
        setStep('disabled');
        setDisablePassword('');
        setDisableCode('');
      } else {
        const err = await res.json();
        setError(err.detail || 'Could not disable MFA');
      }
    } catch {
      setError('Request failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-800">Two-Factor Authentication</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-xl leading-none">&times;</button>
        </div>

        <div className="p-5">
          {/* Success message */}
          {successMsg && (
            <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-lg text-green-700 text-sm">
              {successMsg}
            </div>
          )}

          {/* Error message */}
          {error && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-red-600 text-sm">
              {error}
            </div>
          )}

          {/* Loading */}
          {step === 'loading' && (
            <div className="text-center py-8 text-gray-500">Checking MFA status...</div>
          )}

          {/* MFA Disabled — show enable button */}
          {step === 'disabled' && (
            <div className="text-center">
              <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <span className="text-3xl">🔓</span>
              </div>
              <p className="text-gray-600 mb-2">Two-factor authentication is <span className="font-semibold text-gray-800">not enabled</span>.</p>
              <p className="text-gray-500 text-sm mb-6">Add an extra layer of security by requiring a code from your authenticator app when you sign in.</p>
              <button
                onClick={handleSetup}
                disabled={loading}
                className="w-full bg-teal-700 text-white py-2.5 rounded-lg font-semibold hover:bg-teal-800 transition-colors disabled:opacity-50"
              >
                {loading ? 'Setting up...' : 'Enable Two-Factor Authentication'}
              </button>
            </div>
          )}

          {/* QR Code step — scan and verify */}
          {step === 'qr' && (
            <div>
              <div className="text-center mb-4">
                <p className="text-gray-700 font-medium mb-1">Step 1: Scan this QR code</p>
                <p className="text-gray-500 text-sm">Open <strong>Google Authenticator</strong> (or any TOTP app), tap <strong>+</strong>, then scan:</p>
              </div>

              {/* QR Code */}
              <div className="flex justify-center mb-4">
                <img src={qrCode} alt="MFA QR Code" className="w-48 h-48 border rounded-lg" />
              </div>

              {/* Manual entry fallback */}
              <details className="mb-5">
                <summary className="text-sm text-teal-700 cursor-pointer hover:underline">Can't scan? Enter key manually</summary>
                <div className="mt-2 p-3 bg-gray-50 rounded-lg">
                  <p className="text-xs text-gray-500 mb-1">Enter this key in your authenticator app:</p>
                  <code className="text-sm font-mono bg-white px-2 py-1 rounded border select-all break-all">{secret}</code>
                </div>
              </details>

              {/* Verify code */}
              <form onSubmit={handleVerify}>
                <p className="text-gray-700 font-medium mb-2">Step 2: Enter the 6-digit code</p>
                <p className="text-gray-500 text-sm mb-3">Type the code shown in your authenticator app to confirm setup:</p>
                <input
                  type="text"
                  inputMode="numeric"
                  pattern="[0-9]{6}"
                  maxLength={6}
                  value={verifyCode}
                  onChange={e => { setVerifyCode(e.target.value.replace(/\D/g, '')); setError(''); }}
                  className="w-full px-3 py-2.5 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500 text-center text-2xl tracking-widest mb-4"
                  placeholder="000000"
                  autoFocus
                  required
                />
                <button
                  type="submit"
                  disabled={loading || verifyCode.length !== 6}
                  className="w-full bg-teal-700 text-white py-2.5 rounded-lg font-semibold hover:bg-teal-800 transition-colors disabled:opacity-50"
                >
                  {loading ? 'Verifying...' : 'Verify & Enable'}
                </button>
              </form>
            </div>
          )}

          {/* MFA Enabled — show status and disable option */}
          {step === 'enabled' && (
            <div className="text-center">
              <div className="w-16 h-16 bg-green-50 rounded-full flex items-center justify-center mx-auto mb-4">
                <span className="text-3xl">🔐</span>
              </div>
              <p className="text-gray-600 mb-1">Two-factor authentication is <span className="font-semibold text-green-700">enabled</span>.</p>
              <p className="text-gray-500 text-sm mb-6">You'll need your authenticator app code each time you sign in.</p>
              <button
                onClick={() => { setStep('disable-confirm'); setError(''); setSuccessMsg(''); }}
                className="w-full border border-red-300 text-red-600 py-2.5 rounded-lg font-semibold hover:bg-red-50 transition-colors"
              >
                Disable Two-Factor Authentication
              </button>
            </div>
          )}

          {/* Disable confirmation — requires password + TOTP */}
          {step === 'disable-confirm' && (
            <form onSubmit={handleDisable}>
              <p className="text-gray-700 font-medium mb-1">Disable Two-Factor Authentication</p>
              <p className="text-gray-500 text-sm mb-4">Enter your password and current authenticator code to confirm:</p>
              <div className="mb-3">
                <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
                <input
                  type="password"
                  value={disablePassword}
                  onChange={e => { setDisablePassword(e.target.value); setError(''); }}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
                  required
                  autoFocus
                />
              </div>
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-1">Authenticator Code</label>
                <input
                  type="text"
                  inputMode="numeric"
                  pattern="[0-9]{6}"
                  maxLength={6}
                  value={disableCode}
                  onChange={e => { setDisableCode(e.target.value.replace(/\D/g, '')); setError(''); }}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500 text-center text-lg tracking-widest"
                  placeholder="000000"
                  required
                />
              </div>
              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={() => { setStep('enabled'); setError(''); }}
                  className="flex-1 border border-gray-300 text-gray-600 py-2.5 rounded-lg font-semibold hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={loading || disableCode.length !== 6 || !disablePassword}
                  className="flex-1 bg-red-600 text-white py-2.5 rounded-lg font-semibold hover:bg-red-700 transition-colors disabled:opacity-50"
                >
                  {loading ? 'Disabling...' : 'Disable'}
                </button>
              </div>
            </form>
          )}
        </div>
      </div>
    </div>
  );
};

export default MfaSetup;
