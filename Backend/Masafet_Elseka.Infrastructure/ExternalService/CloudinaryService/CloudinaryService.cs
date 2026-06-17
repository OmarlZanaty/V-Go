using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Masafet_Elseka.Application.ExternalInterfaces.ICloudinaryService;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.CloudinaryService
{
    public class CloudinaryService:ICloudinaryService
    {
        private readonly IConfiguration _configuration;
        private Cloudinary? _cloudinaryInstance;

        public CloudinaryService(IConfiguration configuration)
        {
            // Build the Cloudinary client lazily so a missing config doesn't crash
            // app startup (the client is only needed when an upload is performed).
            _configuration = configuration;
        }

        private Cloudinary _cloudinary
        {
            get
            {
                if (_cloudinaryInstance == null)
                {
                    var account = new Account
                    {
                        Cloud = _configuration["Cloudinary:CloudName"],
                        ApiKey = _configuration["Cloudinary:ApiKey"],
                        ApiSecret = _configuration["Cloudinary:ApiSecret"]
                    };
                    _cloudinaryInstance = new Cloudinary(account);
                }
                return _cloudinaryInstance;
            }
        }


        public async Task<(string PublicId, string Url)> UploadFileAsync(IFormFile file, string folderName = "general")
        {
            if (file == null || file.Length == 0)
                return (string.Empty, string.Empty);

            var originalFileName = file.FileName;
            var fileExtension = Path.GetExtension(originalFileName).ToLower();
            var fileName = !string.IsNullOrEmpty(originalFileName)
                ? originalFileName
                : $"{Guid.NewGuid()}{fileExtension}";

            using var stream = file.OpenReadStream();

            bool isImage = new[] { ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".svg", ".webp" }.Contains(fileExtension);

            var uploadParams = isImage
                ? new ImageUploadParams
                {
                    File = new FileDescription(fileName, stream),
                    Folder = folderName,
                    UseFilename = true,
                    UniqueFilename = true
                }
                : new RawUploadParams
                {
                    File = new FileDescription(fileName, stream),
                    Folder = folderName,
                    UseFilename = true,
                    UniqueFilename = false
                };

            var uploadResult = await _cloudinary.UploadAsync(uploadParams);

            string publicId = uploadResult.PublicId;
            string fileUrl = uploadResult.SecureUrl.ToString();

            return (publicId, fileUrl);
        }

        public async Task<bool> DeleteFileAsync(string publicId)
        {
            if (string.IsNullOrEmpty(publicId))
                return false;

            try
            {
                var resource = await _cloudinary.GetResourceAsync(new GetResourceParams(publicId));

                if (resource == null)
                {
                    return false;
                }

                string resourceTypeString = resource.ResourceType.ToString().ToLower();

                ResourceType resourceType = resourceTypeString switch
                {
                    "image" => ResourceType.Image,
                    "video" => ResourceType.Video,
                    "raw" => ResourceType.Raw,
                    _ => ResourceType.Auto
                };

                var deletionParams = new DeletionParams(publicId)
                {
                    Invalidate = true,
                    ResourceType = resourceType
                };

                var deletionResult = await _cloudinary.DestroyAsync(deletionParams);

                return deletionResult.Result == "ok";
            }
            catch (Exception ex)
            {
                return false;
            }
        }



        string ICloudinaryService.GetFileUrl(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
                return string.Empty;
            // Already a full URL (most stored values) — return as-is.
            if (path.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
                path.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
                return path;
            // Otherwise treat it as a Cloudinary public id and build a secure URL.
            return _cloudinary.Api.UrlImgUp.Secure(true).BuildUrl(path);
        }


    }
}
