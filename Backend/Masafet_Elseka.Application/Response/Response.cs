using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Response
{
    public class Response<T>
    {
        public bool IsSuccess { get; private set; }
        public T Data { get; private set; }
        public string Message { get; private set; }
        public int StatusCode { get; private set; }
        public List<string> Errors { get; private set; }

        private Response(bool isSuccess, T data, string message, int statusCode, List<string> errors)
        {
            IsSuccess = isSuccess;
            Data = data;
            Message = message;
            StatusCode = statusCode;
            Errors=errors;
        }

        public static Response<T> Success(T data, string message = "", int statusCode = 200)
            => new Response<T>(true, data, message, statusCode,null);

        public static Response<T> Failure(string message, int statusCode = 400, List<string> errors = null)
             => new Response<T>(false, default, message, statusCode, errors);

        public static Response<T> Failure(T data, string message, int statusCode = 400, List<string> errors = null)
           => new Response<T>(false, data, message, statusCode, errors);
    }
}