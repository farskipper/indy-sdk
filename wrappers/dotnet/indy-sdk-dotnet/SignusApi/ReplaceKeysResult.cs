﻿using System;

namespace Hyperledger.Indy.SignusApi
{
    /// <summary>
    /// Result of replacing keys.
    /// </summary>
    public sealed class ReplaceKeysStartResult
    {
        /// <summary>
        /// Initializes a new ReplaceKeysResult.
        /// </summary>
        /// <param name="verKey">The verification key.</param>
        /// <param name="pk">The primary key.</param>
        internal ReplaceKeysStartResult(string verKey, string pk)
        {
            VerKey = verKey ?? throw new ArgumentNullException("verKey"); 
            Pk = pk ?? throw new ArgumentNullException("pk"); 
        }

        /// <summary>
        /// Gets the verification key.
        /// </summary>
        public string VerKey { get; }

        /// <summary>
        /// Gets the primary key.
        /// </summary>
        public string Pk { get; }

    }
}
