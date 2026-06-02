using Masafet_Elseka.Application.DTOs.UserTripDTO;
using Masafet_Elseka.Application.Interfaces.IUserTripService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.UOW;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.UserTripService
{
    public class UserTripService: IUserTripService
    {

        private readonly IUnitOfWork _unitOfWork;
        public UserTripService(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork;
        }

        public async Task<Response<string>> AssignUserToTrip(UserTripDTO model)
        {
            try
            {
                if (model == null)
                {
                    return Response<string>.Failure("نموذج البيانات غير صالح", 400);
                }
                if (model.Role == UserTripRole.Driver)
                {
                    bool driverAlreadyAssigned = await _unitOfWork.UserTrips
                        .AnyAsync(ut => ut.TripId == model.TripId && ut.Role == UserTripRole.Driver);

                    if (driverAlreadyAssigned)
                    {
                        return Response<string>.Failure("تم تعيين سائق آخر لهذه الرحلة بالفعل", 409);
                    }
                }
                var userTrip = new Domain.Entities.UserTrip
                {
                    Id = Guid.NewGuid().ToString(),
                    UserId = model.UserId,
                    TripId = model.TripId,
                    Date = DateTime.Now.ToEgyptTime(),
                    IsApproved=false,
                    Role = model.Role
                };
                var validator= new UserTripValidator().Validate(userTrip);
                if (!validator.IsValid)
                {
                    var errors = validator.Errors.Select(e => e.ErrorMessage).ToList();
                    return Response<string>.Failure("التحقق من صحة البيانات فشل", 400, errors);
                }
                if (model.Role == UserTripRole.Driver)
                {
                    userTrip.IsApproved = true; 
                }
                await _unitOfWork.UserTrips.AddAsync(userTrip);
                await _unitOfWork.SaveAsync();
                return Response<string>.Success($"تمت اضافة العميل لرحلة  {model.TripId} ", $"تمت اضافة العميل لرحلة  {model.TripId} ",201);
            }
            catch (Exception ex)
            {
                return Response<string>.Failure("حدث خطأ أثناء العميل للرحلة", ex.Message, 500);
            }
        }
    }
}
