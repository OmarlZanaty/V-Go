using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.ExternalInterfaces.ICloudinaryService
{
    public interface ICloudinaryService
    {
        public string GetFileUrl(string path);
        public Task<(string PublicId, string Url)> UploadFileAsync(IFormFile file, string folderName = "general");
        public Task<bool> DeleteFileAsync(string publicId);
    }
}
