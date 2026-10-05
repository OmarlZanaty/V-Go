using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.DriverVerification;
using Masafet_Elseka.Application.ExternalInterfaces.ICloudinaryService;
using Masafet_Elseka.Application.Interfaces.IDriverFinanceService;
using Masafet_Elseka.Application.Interfaces.IDriverVerificationService;
using Masafet_Elseka.Application.Interfaces.INotificationService;
using Masafet_Elseka.Application.Interfaces.IPrivateFileStorage;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Serilog;
using FinanceService = Masafet_Elseka.Infrastructure.Services.DriverFinanceService.DriverFinanceService;

namespace Masafet_Elseka.Infrastructure.Services.DriverVerificationService
{
    // Captain KYC: selfie + national ID (both sides) + driving licence + vehicle licence.
    // A captain can use the app while documents are pending but can't go online until
    // an admin approves them (enforced by DriverFinanceService eligibility).
    public class DriverVerificationService : IDriverVerificationService
    {
        private const long MaxFileBytes = 8 * 1024 * 1024;

        private readonly Context _context;
        private readonly ICloudinaryService _cloudinary;
        private readonly IPrivateFileStorage _storage;
        private readonly IPublicMediaStorage _publicMedia;
        private readonly IDriverFinanceService _finance;
        private readonly INotificationService _notificationService;
        private readonly IConfiguration _configuration;

        public DriverVerificationService(Context context, ICloudinaryService cloudinary, IPrivateFileStorage storage,
            IPublicMediaStorage publicMedia, IDriverFinanceService finance, INotificationService notificationService,
            IConfiguration configuration)
        {
            _context = context;
            _cloudinary = cloudinary;
            _storage = storage;
            _publicMedia = publicMedia;
            _finance = finance;
            _notificationService = notificationService;
            _configuration = configuration;
        }

        // The selfie is public (riders see it). Cloudinary when the host has it configured,
        // otherwise the server's own /media folder.
        private async Task<string?> SavePublicPhotoAsync(IFormFile file, string extension)
        {
            try
            {
                if (!string.IsNullOrWhiteSpace(_configuration["Cloudinary:CloudName"]))
                {
                    var (_, url) = await _cloudinary.UploadFileAsync(file, "ProfilePictures");
                    if (!string.IsNullOrEmpty(url)) return url;
                }
                await using var stream = file.OpenReadStream();
                return await _publicMedia.SaveAsync(stream, "profile", extension);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Saving captain selfie failed");
                return null;
            }
        }

        private static DateTime Now => DateTime.Now.ToEgyptTime();
        private static DriverDocumentType[] Required => FinanceService.RequiredDocuments;

        private static bool NeedsExpiry(DriverDocumentType type) =>
            type is DriverDocumentType.DriverLicense or DriverDocumentType.VehicleLicense;

        private static DriverDocumentDTO ToDto(DriverDocument d) => new()
        {
            Id = d.Id,
            Type = d.Type.ToString(),
            Status = d.Status.ToString(),
            ExpiryDate = d.ExpiryDate,
            RejectionReason = d.RejectionReason,
            UploadedAt = d.UploadedAt,
            ReviewedAt = d.ReviewedAt,
            PublicUrl = d.IsPublic ? d.FilePath : null,
        };

        private IQueryable<ApplicationUser> DriversQuery() =>
            from u in _context.Users
            join ur in _context.UserRoles on u.Id equals ur.UserId
            join r in _context.Roles on ur.RoleId equals r.Id
            where r.Name == "Driver"
            select u;

        // Sniffs the real format instead of trusting the client's content type.
        private static (string Extension, string ContentType)? DetectImage(byte[] head)
        {
            if (head.Length >= 3 && head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF)
                return (".jpg", "image/jpeg");
            if (head.Length >= 8 && head[0] == 0x89 && head[1] == 0x50 && head[2] == 0x4E && head[3] == 0x47)
                return (".png", "image/png");
            if (head.Length >= 12 && head[0] == 'R' && head[1] == 'I' && head[2] == 'F' && head[3] == 'F'
                && head[8] == 'W' && head[9] == 'E' && head[10] == 'B' && head[11] == 'P')
                return (".webp", "image/webp");
            return null;
        }

        #region Captain

        public async Task<Response<DriverVerificationDTO>> GetForDriverAsync(string driverId)
        {
            var user = await DriversQuery().AsNoTracking().FirstOrDefaultAsync(u => u.Id == driverId);
            if (user == null) return Response<DriverVerificationDTO>.Failure("الكابتن غير موجود", 404);
            return Response<DriverVerificationDTO>.Success(await BuildDtoAsync(user), "", 200);
        }

        private async Task<DriverVerificationDTO> BuildDtoAsync(ApplicationUser user)
        {
            var docs = await _context.DriverDocuments.AsNoTracking()
                .Where(d => d.DriverId == user.Id).ToListAsync();
            var eligibility = await _finance.CheckOnlineEligibilityAsync(user.Id);
            var usable = docs.Where(d => d.Status != DriverDocumentStatus.Rejected).Select(d => d.Type).ToHashSet();

            return new DriverVerificationDTO
            {
                DriverId = user.Id,
                Name = user.FullName,
                Phone = user.PhoneNumber,
                ProfilePicture = user.ProfilePicture,
                Status = user.VerificationStatus.ToString(),
                Note = user.VerificationNote,
                DocumentsDeadline = user.DocumentsDeadline,
                Documents = docs.OrderBy(d => d.Type).Select(ToDto).ToList(),
                RequiredTypes = Required.Select(t => t.ToString()).ToList(),
                MissingTypes = Required.Where(t => !usable.Contains(t)).Select(t => t.ToString()).ToList(),
                CanGoOnline = eligibility.CanGoOnline,
                BlockCode = eligibility.Code,
                BlockMessage = eligibility.Message,
            };
        }

        public async Task<Response<DriverDocumentDTO>> UploadDocumentAsync(string driverId, string type, IFormFile file, DateTime? expiryDate)
        {
            if (!Enum.TryParse<DriverDocumentType>(type, true, out var docType) || !Enum.IsDefined(docType))
                return Response<DriverDocumentDTO>.Failure("نوع المستند غير صالح", 400);
            if (file == null || file.Length == 0)
                return Response<DriverDocumentDTO>.Failure("ارفع صورة المستند", 400);
            if (file.Length > MaxFileBytes)
                return Response<DriverDocumentDTO>.Failure("حجم الصورة كبير، الحد الأقصى 8 ميجا", 400);

            if (NeedsExpiry(docType))
            {
                if (expiryDate == null)
                    return Response<DriverDocumentDTO>.Failure("اكتب تاريخ انتهاء الرخصة", 400);
                if (expiryDate.Value.Date <= Now.Date)
                    return Response<DriverDocumentDTO>.Failure("الرخصة منتهية، ارفع رخصة سارية", 400);
            }
            else
            {
                expiryDate = null;
            }

            var user = await DriversQuery().FirstOrDefaultAsync(u => u.Id == driverId);
            if (user == null) return Response<DriverDocumentDTO>.Failure("الكابتن غير موجود", 404);
            if (user.VerificationStatus == DriverVerificationStatus.Suspended)
                return Response<DriverDocumentDTO>.Failure("حسابك موقوف، تواصل مع الدعم", 403);

            var head = new byte[12];
            await using (var probe = file.OpenReadStream())
            {
                var read = await probe.ReadAsync(head.AsMemory(0, head.Length));
                if (read < head.Length) Array.Resize(ref head, read);
            }
            var format = DetectImage(head);
            if (format == null)
                return Response<DriverDocumentDTO>.Failure("الملف لازم يكون صورة (JPG أو PNG)", 400);

            string path;
            bool isPublic;
            if (docType == DriverDocumentType.Selfie)
            {
                // The selfie is the captain's public profile photo riders see.
                var url = await SavePublicPhotoAsync(file, format.Value.Extension);
                if (string.IsNullOrEmpty(url))
                    return Response<DriverDocumentDTO>.Failure("تعذّر رفع الصورة، حاول تاني", 500);
                path = url;
                isPublic = true;
                user.ProfilePicture = url;
            }
            else
            {
                await using var stream = file.OpenReadStream();
                path = await _storage.SaveAsync(stream, $"driver-docs/{driverId}", format.Value.Extension);
                isPublic = false;
            }

            var doc = await _context.DriverDocuments.FirstOrDefaultAsync(d => d.DriverId == driverId && d.Type == docType);
            var oldPrivatePath = doc != null && !doc.IsPublic ? doc.FilePath : null;
            if (doc == null)
            {
                doc = new DriverDocument { DriverId = driverId, Type = docType };
                _context.DriverDocuments.Add(doc);
            }
            doc.FilePath = path;
            doc.IsPublic = isPublic;
            doc.ContentType = format.Value.ContentType;
            doc.ExpiryDate = expiryDate;
            doc.Status = DriverDocumentStatus.Pending;
            doc.RejectionReason = null;
            doc.ReviewedAt = null;
            doc.ReviewedByUserId = null;
            doc.UploadedAt = Now;

            await _context.SaveChangesAsync();
            if (oldPrivatePath != null) _storage.Delete(oldPrivatePath);

            var becameReviewable = await RecomputeStatusAfterUploadAsync(user);
            _finance.InvalidateEligibility(driverId);
            if (becameReviewable) await NotifyAdminsAsync(user);

            return Response<DriverDocumentDTO>.Success(ToDto(doc), "تم رفع المستند", 200);
        }

        // Returns true when the captain just moved to "under review".
        private async Task<bool> RecomputeStatusAfterUploadAsync(ApplicationUser user)
        {
            if (user.VerificationStatus is not (DriverVerificationStatus.PendingDocuments or DriverVerificationStatus.Rejected))
                return false; // approved (grace period) or already under review: nothing to move

            var docs = await _context.DriverDocuments.AsNoTracking().Where(d => d.DriverId == user.Id).ToListAsync();
            var anyRejected = docs.Any(d => d.Status == DriverDocumentStatus.Rejected);
            var complete = Required.All(t => docs.Any(d => d.Type == t && d.Status != DriverDocumentStatus.Rejected));

            var next = complete && !anyRejected ? DriverVerificationStatus.UnderReview
                : anyRejected ? DriverVerificationStatus.Rejected
                : DriverVerificationStatus.PendingDocuments;
            if (next == user.VerificationStatus) return false;

            user.VerificationStatus = next;
            if (next == DriverVerificationStatus.UnderReview) user.VerificationNote = null;
            await _context.SaveChangesAsync();
            return next == DriverVerificationStatus.UnderReview;
        }

        private async Task NotifyAdminsAsync(ApplicationUser driver)
        {
            try
            {
                var adminIds = await (from u in _context.Users
                                      join ur in _context.UserRoles on u.Id equals ur.UserId
                                      join r in _context.Roles on ur.RoleId equals r.Id
                                      where r.Name == "Admin" || r.Name == "Dispatcher"
                                      select u.Id).Distinct().ToListAsync();
                foreach (var adminId in adminIds)
                {
                    await _notificationService.SendNotificationToUserAsync(adminId, "كابتن مستني المراجعة",
                        $"{driver.FullName} رفع كل المستندات وفي انتظار الموافقة",
                        new Dictionary<string, string> { { "type", "driver_verification_pending" }, { "driverId", driver.Id } });
                }
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "Admin notify for driver review failed");
            }
        }

        private async Task NotifyDriverAsync(string driverId, string title, string body, string type)
        {
            try
            {
                await _notificationService.SendNotificationToUserAsync(driverId, title, body,
                    new Dictionary<string, string> { { "type", type } });
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "Driver verification notify failed for {DriverId}", driverId);
            }
        }

        #endregion

        #region Admin

        public async Task<Response<PaginationPagedResponse<VerificationQueueItemDTO>>> GetQueueAsync(PaginationRequest pagination, string? status, string? search)
        {
            var page = Math.Max(1, pagination.PageNumber);
            var size = Math.Clamp(pagination.PageSize, 1, 100);

            var query = DriversQuery().AsNoTracking().Select(u => new
            {
                User = u,
                Uploaded = _context.DriverDocuments.Count(d => d.DriverId == u.Id),
                Pending = _context.DriverDocuments.Count(d => d.DriverId == u.Id && d.Status == DriverDocumentStatus.Pending),
                Rejected = _context.DriverDocuments.Count(d => d.DriverId == u.Id && d.Status == DriverDocumentStatus.Rejected),
                LastUpload = _context.DriverDocuments.Where(d => d.DriverId == u.Id).Max(d => (DateTime?)d.UploadedAt),
            });

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim();
                query = query.Where(x => x.User.FullName.Contains(s) || (x.User.PhoneNumber != null && x.User.PhoneNumber.Contains(s)));
            }

            var filter = (status ?? "needsreview").ToLowerInvariant();
            query = filter switch
            {
                // Anything an admin has to look at: complete sets plus re-uploads from
                // already-approved captains.
                "needsreview" => query.Where(x => x.User.VerificationStatus == DriverVerificationStatus.UnderReview || x.Pending > 0),
                "all" => query,
                _ when Enum.TryParse<DriverVerificationStatus>(status, true, out var st) => query.Where(x => x.User.VerificationStatus == st),
                _ => query,
            };

            var total = await query.CountAsync();
            var rows = await query
                .OrderByDescending(x => x.LastUpload ?? x.User.CreatedAt)
                .Skip((page - 1) * size).Take(size)
                .ToListAsync();

            var items = rows.Select(x => new VerificationQueueItemDTO
            {
                DriverId = x.User.Id,
                Name = x.User.FullName,
                Phone = x.User.PhoneNumber,
                ProfilePicture = x.User.ProfilePicture,
                Status = x.User.VerificationStatus.ToString(),
                UploadedCount = x.Uploaded,
                PendingCount = x.Pending,
                RejectedCount = x.Rejected,
                LastUploadAt = x.LastUpload,
                DocumentsDeadline = x.User.DocumentsDeadline,
                CreatedAt = x.User.CreatedAt,
            }).ToList();

            return Response<PaginationPagedResponse<VerificationQueueItemDTO>>.Success(
                new PaginationPagedResponse<VerificationQueueItemDTO>(items, total, page, size), "", 200);
        }

        public async Task<Response<DocumentFileDTO>> GetDocumentFileAsync(string documentId)
        {
            var doc = await _context.DriverDocuments.AsNoTracking().FirstOrDefaultAsync(d => d.Id == documentId);
            if (doc == null) return Response<DocumentFileDTO>.Failure("المستند غير موجود", 404);
            if (doc.IsPublic) return Response<DocumentFileDTO>.Failure("هذه الصورة عامة، استخدم الرابط المباشر", 400);

            var bytes = await _storage.ReadAsync(doc.FilePath);
            if (bytes == null) return Response<DocumentFileDTO>.Failure("ملف المستند غير موجود على السيرفر", 404);

            return Response<DocumentFileDTO>.Success(new DocumentFileDTO
            {
                Content = bytes,
                ContentType = doc.ContentType,
                FileName = $"{doc.Type}{Path.GetExtension(doc.FilePath)}",
            }, "", 200);
        }

        public async Task<Response<DriverDocumentDTO>> ReviewDocumentAsync(string documentId, ReviewDocumentDTO dto, string actorUserId)
        {
            var doc = await _context.DriverDocuments.FirstOrDefaultAsync(d => d.Id == documentId);
            if (doc == null) return Response<DriverDocumentDTO>.Failure("المستند غير موجود", 404);
            var reason = dto.Reason?.Trim();
            if (!dto.Approve && string.IsNullOrWhiteSpace(reason))
                return Response<DriverDocumentDTO>.Failure("اكتب سبب الرفض علشان الكابتن يعرف يصلّح", 400);

            var user = await _context.Users.FirstAsync(u => u.Id == doc.DriverId);
            doc.Status = dto.Approve ? DriverDocumentStatus.Approved : DriverDocumentStatus.Rejected;
            doc.RejectionReason = dto.Approve ? null : reason;
            doc.ReviewedAt = Now;
            doc.ReviewedByUserId = actorUserId;
            await _context.SaveChangesAsync();

            var docs = await _context.DriverDocuments.AsNoTracking().Where(d => d.DriverId == user.Id).ToListAsync();
            var allApproved = Required.All(t => docs.Any(d => d.Type == t && d.Status == DriverDocumentStatus.Approved));
            var inGrace = user.VerificationStatus == DriverVerificationStatus.Approved
                && user.DocumentsDeadline.HasValue && Now < user.DocumentsDeadline.Value;

            if (!dto.Approve)
            {
                // A grandfathered captain keeps working until his grace period ends;
                // anyone else stops until the document is fixed.
                if (!inGrace && user.VerificationStatus != DriverVerificationStatus.Suspended)
                {
                    user.VerificationStatus = DriverVerificationStatus.Rejected;
                    user.VerificationNote = reason;
                }
                await _context.SaveChangesAsync();
                await NotifyDriverAsync(user.Id, "مستند محتاج يتعدّل",
                    $"تم رفض {DocumentName(doc.Type)}: {reason}. أعد رفعه من صفحة التوثيق.", "driver_document_rejected");
            }
            else if (allApproved && user.VerificationStatus != DriverVerificationStatus.Suspended)
            {
                var wasApproved = user.VerificationStatus == DriverVerificationStatus.Approved;
                user.VerificationStatus = DriverVerificationStatus.Approved;
                user.VerificationNote = null;
                user.DocumentsDeadline = null; // fully verified now
                await _context.SaveChangesAsync();
                if (!wasApproved)
                    await NotifyDriverAsync(user.Id, "تم توثيق حسابك 🎉", "تمت الموافقة على مستنداتك، تقدر تبدأ تشتغل دلوقتي.", "driver_verification_approved");
            }

            await _finance.WriteAuditAsync(actorUserId, dto.Approve ? "DocumentApproved" : "DocumentRejected", user.Id,
                $"{doc.Type}" + (dto.Approve ? "" : $": {reason}"));
            await _finance.EnforceEligibilityAsync(user.Id);
            return Response<DriverDocumentDTO>.Success(ToDto(doc), dto.Approve ? "تمت الموافقة على المستند" : "تم رفض المستند", 200);
        }

        public async Task<Response<DriverVerificationDTO>> DecideAsync(string driverId, VerificationDecisionDTO dto, string actorUserId)
        {
            if (!Enum.TryParse<DriverVerificationStatus>(dto.Status, true, out var target)
                || target is not (DriverVerificationStatus.Approved or DriverVerificationStatus.Rejected or DriverVerificationStatus.Suspended))
                return Response<DriverVerificationDTO>.Failure("القرار لازم يكون موافقة أو رفض أو إيقاف", 400);

            var user = await DriversQuery().FirstOrDefaultAsync(u => u.Id == driverId);
            if (user == null) return Response<DriverVerificationDTO>.Failure("الكابتن غير موجود", 404);
            var note = dto.Note?.Trim();

            if (target == DriverVerificationStatus.Approved)
            {
                var docs = await _context.DriverDocuments.Where(d => d.DriverId == driverId).ToListAsync();
                var missing = Required.Where(t => !docs.Any(d => d.Type == t && d.Status != DriverDocumentStatus.Rejected)).ToList();
                if (missing.Count > 0)
                    return Response<DriverVerificationDTO>.Failure(
                        "لا يمكن الموافقة: مستندات ناقصة أو مرفوضة (" + string.Join("، ", missing.Select(DocumentName)) + ")", 400);

                // Approving the captain approves every document still waiting.
                foreach (var d in docs.Where(d => d.Status == DriverDocumentStatus.Pending))
                {
                    d.Status = DriverDocumentStatus.Approved;
                    d.ReviewedAt = Now;
                    d.ReviewedByUserId = actorUserId;
                }
                user.DocumentsDeadline = null;
            }
            else if (string.IsNullOrWhiteSpace(note))
            {
                return Response<DriverVerificationDTO>.Failure("اكتب السبب علشان يظهر للكابتن", 400);
            }

            var previous = user.VerificationStatus;
            user.VerificationStatus = target;
            user.VerificationNote = target == DriverVerificationStatus.Approved ? null : note;
            await _context.SaveChangesAsync();

            await _finance.WriteAuditAsync(actorUserId, $"Verification{target}", driverId, $"{previous} -> {target}" + (note == null ? "" : $": {note}"));
            await _finance.EnforceEligibilityAsync(driverId);

            var (title, body) = target switch
            {
                DriverVerificationStatus.Approved => ("تم توثيق حسابك 🎉", "تمت الموافقة على حسابك، تقدر تبدأ تشتغل دلوقتي."),
                DriverVerificationStatus.Rejected => ("طلب التوثيق محتاج تعديل", $"السبب: {note}"),
                _ => ("تم إيقاف حسابك", $"السبب: {note}"),
            };
            await NotifyDriverAsync(driverId, title, body, "driver_verification_" + target.ToString().ToLowerInvariant());

            return Response<DriverVerificationDTO>.Success(await BuildDtoAsync(user), "تم حفظ القرار", 200);
        }

        private static string DocumentName(DriverDocumentType type) => type switch
        {
            DriverDocumentType.Selfie => "الصورة الشخصية",
            DriverDocumentType.NationalIdFront => "البطاقة (وش)",
            DriverDocumentType.NationalIdBack => "البطاقة (ظهر)",
            DriverDocumentType.DriverLicense => "رخصة القيادة",
            DriverDocumentType.VehicleLicense => "رخصة العربية",
            _ => type.ToString(),
        };

        #endregion
    }
}
