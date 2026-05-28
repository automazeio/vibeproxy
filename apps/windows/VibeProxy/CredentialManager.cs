using System;
using System.Runtime.InteropServices;
using System.Text;

namespace VibeProxy;

/// <summary>
/// Windows Credential Manager integration for secure credential storage
/// </summary>
public static class CredentialManager
{
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredWrite(ref Credential credential, uint flags);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredRead(string target, CredentialType type, int reservedFlag, out IntPtr credentialPtr);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool CredFree(IntPtr buffer);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredDelete(string target, CredentialType type, int reservedFlag);

    private enum CredentialType
    {
        Generic = 1,
        DomainPassword = 2,
        DomainCertificate = 3,
        DomainVisiblePassword = 4,
        GenericCertificate = 5,
        DomainExtended = 6,
        Maximum = 7
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct Credential
    {
        public uint flags;
        public CredentialType type;
        public string targetName;
        public string comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME lastWritten;
        public uint credentialBlobSize;
        public IntPtr credentialBlob;
        public uint persist;
        public uint attributeCount;
        public IntPtr attributes;
        public string targetAlias;
        public string userName;
    }

    private const uint CRED_PERSIST_LOCAL_MACHINE = 2;
    private const uint CRED_PERSIST_ENTERPRISE = 3;

    /// <summary>
    /// Saves a credential to Windows Credential Manager
    /// </summary>
    public static bool SaveCredential(string target, string username, string password, string? comment = null)
    {
        try
        {
            byte[] passwordBytes = Encoding.Unicode.GetBytes(password);
            IntPtr passwordPtr = Marshal.AllocCoTaskMem(passwordBytes.Length);
            Marshal.Copy(passwordBytes, 0, passwordPtr, passwordBytes.Length);

            var credential = new Credential
            {
                flags = 0,
                type = CredentialType.Generic,
                targetName = target,
                comment = comment ?? "VibeProxy credential",
                credentialBlobSize = (uint)passwordBytes.Length,
                credentialBlob = passwordPtr,
                persist = CRED_PERSIST_LOCAL_MACHINE,
                attributeCount = 0,
                attributes = IntPtr.Zero,
                targetAlias = null,
                userName = username
            };

            bool result = CredWrite(ref credential, 0);
            Marshal.FreeCoTaskMem(passwordPtr);
            return result;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// Retrieves a credential from Windows Credential Manager
    /// </summary>
    public static (string username, string password)? GetCredential(string target)
    {
        try
        {
            if (!CredRead(target, CredentialType.Generic, 0, out IntPtr credentialPtr))
            {
                return null;
            }

            var credential = Marshal.PtrToStructure<Credential>(credentialPtr);
            
            byte[] passwordBytes = new byte[credential.credentialBlobSize];
            Marshal.Copy(credential.credentialBlob, passwordBytes, 0, (int)credential.credentialBlobSize);
            string password = Encoding.Unicode.GetString(passwordBytes);
            string username = credential.userName;

            CredFree(credentialPtr);
            return (username, password);
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// Deletes a credential from Windows Credential Manager
    /// </summary>
    public static bool DeleteCredential(string target)
    {
        try
        {
            return CredDelete(target, CredentialType.Generic, 0);
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// Saves an API key securely
    /// </summary>
    public static bool SaveApiKey(string service, string apiKey)
    {
        string target = $"VibeProxy:{service}";
        return SaveCredential(target, service, apiKey, $"API key for {service}");
    }

    /// <summary>
    /// Retrieves an API key
    /// </summary>
    public static string? GetApiKey(string service)
    {
        string target = $"VibeProxy:{service}";
        var credential = GetCredential(target);
        return credential?.password;
    }

    /// <summary>
    /// Deletes an API key
    /// </summary>
    public static bool DeleteApiKey(string service)
    {
        string target = $"VibeProxy:{service}";
        return DeleteCredential(target);
    }
}
