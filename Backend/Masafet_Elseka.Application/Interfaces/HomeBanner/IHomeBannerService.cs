using Masafet_Elseka.Application.Response;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.HomeBanner
{
    public interface IHomeBannerService
    {
        public Task<Response<List<string>>> GetHomeBannersAsync();
        public Task<Response<string>> AddBannersAsync(List<IFormFile> banners);
        public Task<Response<string>> RemoveBannersAsync(List<string> bannersUrls);
    }
}
