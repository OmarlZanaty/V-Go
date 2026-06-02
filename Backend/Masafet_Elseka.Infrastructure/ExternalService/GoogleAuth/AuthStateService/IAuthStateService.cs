using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.Models;

namespace Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.AuthState
{
    public interface IAuthStateService
    {

        void AddState(string state);
        Task<bool> CompleteState(string state, string code);
        GoogleAuth.Models.AuthState GetState(string state);
        void CleanupExpiredStates();
    }
}
