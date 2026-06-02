using Microsoft.AspNetCore.Mvc;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.HTMLResponseService
{
    public class HtmlResponseService : IHtmlResponseService
    {
        public ContentResult GenerateSuccessHtml(string userName)
        {
            var html = $@"
<!DOCTYPE html>
<html>
<head>
    <title>Login Successful</title>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{ 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            display: flex; 
            justify-content: center; 
            align-items: center; 
            min-height: 100vh; 
            margin: 0; 
            background: linear-gradient(135deg, #030407 0%, #252525 100%);
            padding: 20px;
        }}
        
        .container {{ 
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            padding: 40px 30px;
            border-radius: 20px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            text-align: center;
            max-width: 450px;
            width: 100%;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }}
        
        .success-icon {{
            width: 80px;
            height: 80px;
            background: #dce01e;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 20px;
            position: relative;
        }}
        
        .success-icon::before {{
            content: '';
            width: 30px;
            height: 15px;
            border: 4px solid #030407;
            border-top: none;
            border-right: none;
            transform: rotate(-45deg);
            position: absolute;
            top: 28px;
        }}
        
        .title {{
            color: #dce01e;
            font-size: 28px;
            font-weight: 600;
            margin-bottom: 15px;
            letter-spacing: 0.5px;
        }}
        
        .subtitle {{
            color: #FFFFFF;
            font-size: 16px;
            margin-bottom: 25px;
            opacity: 0.9;
            line-height: 1.5;
        }}
        
        @keyframes fadeIn {{
            from {{ opacity: 0; transform: translateY(20px); }}
            to {{ opacity: 1; transform: translateY(0); }}
        }}
        
        .container {{
            animation: fadeIn 0.6s ease-out;
        }}
        
        /* Responsive Design */
        @media (max-width: 480px) {{
            .container {{
                padding: 30px 20px;
                margin: 10px;
            }}
            
            .title {{
                font-size: 24px;
            }}
        }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='success-icon'></div>
        <h1 class='title'>Login Successful</h1>
        <p class='subtitle'>Please close the window and return to the App.</p>
    </div> 
</body>
</html>";

            return new ContentResult
            {
                Content = html,
                ContentType = "text/html"
            };
        }

        public ContentResult GenerateErrorHtml(string title, string message)
        {
            var html = $@"
<!DOCTYPE html>
<html>
<head>
    <title>{title}</title>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{ 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            display: flex; 
            justify-content: center; 
            align-items: center; 
            min-height: 100vh; 
            margin: 0; 
            background: linear-gradient(135deg, #030407 0%, #252525 100%);
            padding: 20px;
        }}
        
        .container {{ 
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            padding: 40px 30px;
            border-radius: 20px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            text-align: center;
            max-width: 450px;
            width: 100%;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }}
        
        .error-icon {{
            width: 80px;
            height: 80px;
            background: #FF7600;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 20px;
            position: relative;
        }}
        
        .error-icon::before,
        .error-icon::after {{
            content: '';
            position: absolute;
            width: 30px;
            height: 4px;
            background: #030407;
            border-radius: 2px;
        }}
        
        .error-icon::before {{
            transform: rotate(45deg);
        }}
        
        .error-icon::after {{
            transform: rotate(-45deg);
        }}
        
        .title {{
            color: #FF7600;
            font-size: 28px;
            font-weight: 600;
            margin-bottom: 15px;
            letter-spacing: 0.5px;
        }}
        
        .error-message {{
            color: #FFFFFF;
            font-size: 16px;
            margin-bottom: 20px;
            opacity: 0.9;
            line-height: 1.6;
            padding: 0 10px;
        }}
        
        .retry-button {{
            background: #FF7600;
            color: #030407;
            border: none;
            padding: 12px 30px;
            border-radius: 25px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            margin-top: 20px;
            transition: all 0.3s ease;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
        
        .retry-button:hover {{
            background: #e56900;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(255, 118, 0, 0.3);
        }}
        
        @keyframes fadeIn {{
            from {{ opacity: 0; transform: translateY(20px); }}
            to {{ opacity: 1; transform: translateY(0); }}
        }}
        
        .container {{
            animation: fadeIn 0.6s ease-out;
        }}
        
        /* Responsive Design */
        @media (max-width: 480px) {{
            .container {{
                padding: 30px 20px;
                margin: 10px;
            }}
            
            .title {{
                font-size: 24px;
            }}
            
            .error-message {{
                font-size: 15px;
            }}
        }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='error-icon'></div>
        
        <h1 class='title'>{title}</h1>
        
        <p class='error-message'>{message}</p>

    </div>
</body>
</html>";

            return new ContentResult
            {
                Content = html,
                ContentType = "text/html"
            };
        }

        public ContentResult GenerateInvalidStateHtml()
        {
            return GenerateErrorHtml(
                "Session Expired",
                "Your login session has expired or is invalid. Please return to the app and try again."
            );
        }
    }
}