with AUnit.Assertions;

with Jpeglib.Errors;
with Jpeglib.Internal.Checked_Arithmetic;
with Jpeglib.Internal.Markers;
with Jpeglib.Internal.Ownership;
with Jpeglib.Results;
with Jpeglib.Version;

package body Jpeglib_Testing.Test_Core is
   use AUnit.Assertions;
   use type Jpeglib.Byte_Count;
   use type Jpeglib.Errors.Error_Code;

   procedure Version_Is_Synchronized (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Error_Identifiers_Are_Stable (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Checked_Arithmetic_Detects_Overflow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Ownership_Reservations_Are_Idempotent (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Markers_Are_Classified (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("core");
   end Name;

   overriding procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Version_Is_Synchronized'Access, "foundation.version.semantic");
      Register_Routine (T, Error_Identifiers_Are_Stable'Access, "foundation.errors.identifiers");
      Register_Routine (T, Checked_Arithmetic_Detects_Overflow'Access, "foundation.arithmetic.overflow");
      Register_Routine (T, Ownership_Reservations_Are_Idempotent'Access, "foundation.ownership.reserve_release");
      Register_Routine (T, Markers_Are_Classified'Access, "foundation.markers.classification");
   end Register_Tests;

   procedure Version_Is_Synchronized (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Jpeglib.Version.Current = "0.1.0-dev", "version mismatch");
   end Version_Is_Synchronized;

   procedure Error_Identifiers_Are_Stable (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert
        (Jpeglib.Errors.Identifier_For (Jpeglib.Errors.Source_Read_Failed) = "jpeg.source.read_failed",
         "source error identifier changed");
      Assert
        (Jpeglib.Errors.Identifier_For (Jpeglib.Errors.Operation_Cancelled) = "jpeg.operation.cancelled",
         "cancel identifier changed");
   end Error_Identifiers_Are_Stable;

   procedure Checked_Arithmetic_Detects_Overflow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Result : constant Jpeglib.Internal.Checked_Arithmetic.Count_Result :=
        Jpeglib.Internal.Checked_Arithmetic.Add (Jpeglib.Byte_Count'Last, 1);
   begin
      Assert (not Jpeglib.Results.Succeeded (Result.Outcome), "overflow was accepted");
      Assert
        (Result.Outcome.First_Error.Code = Jpeglib.Errors.Integer_Overflow,
         "overflow has wrong stable error code");
   end Checked_Arithmetic_Detects_Overflow;

   procedure Ownership_Reservations_Are_Idempotent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Budget : Jpeglib.Internal.Ownership.Byte_Budget;
      First : Jpeglib.Internal.Ownership.Byte_Lease;
      Second : Jpeglib.Internal.Ownership.Byte_Lease;
      Outcome : Jpeglib.Results.Result;
   begin
      Outcome := Jpeglib.Internal.Ownership.Reserve (Budget, 10, 4, First);
      Assert (Jpeglib.Results.Succeeded (Outcome), "first reservation failed");
      Assert (Jpeglib.Internal.Ownership.Used (Budget) = 4, "first reservation charged wrong byte count");
      Assert (Jpeglib.Internal.Ownership.Is_Active (First), "first lease was not active");
      Assert (Jpeglib.Internal.Ownership.Size (First) = 4, "first lease reported wrong size");

      Outcome := Jpeglib.Internal.Ownership.Reserve (Budget, 10, 7, Second);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "over-limit reservation succeeded");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Output_Limit_Exceeded,
         "over-limit reservation used wrong error");
      Assert (Jpeglib.Internal.Ownership.Used (Budget) = 4, "failed reservation changed budget");
      Assert (not Jpeglib.Internal.Ownership.Is_Active (Second), "failed reservation activated lease");

      Outcome := Jpeglib.Internal.Ownership.Reserve (Budget, 10, 6, Second);
      Assert (Jpeglib.Results.Succeeded (Outcome), "second reservation failed");
      Assert (Jpeglib.Internal.Ownership.Used (Budget) = 10, "second reservation charged wrong byte count");

      Outcome := Jpeglib.Internal.Ownership.Release (Budget, First);
      Assert (Jpeglib.Results.Succeeded (Outcome), "first release failed");
      Assert (Jpeglib.Internal.Ownership.Used (Budget) = 6, "first release charged wrong byte count");
      Assert (not Jpeglib.Internal.Ownership.Is_Active (First), "first release left lease active");

      Outcome := Jpeglib.Internal.Ownership.Release (Budget, First);
      Assert (Jpeglib.Results.Succeeded (Outcome), "second first release was not idempotent");
      Assert (Jpeglib.Internal.Ownership.Used (Budget) = 6, "idempotent release changed budget");

      Outcome := Jpeglib.Internal.Ownership.Release (Budget, Second);
      Assert (Jpeglib.Results.Succeeded (Outcome), "second release failed");
      Assert (Jpeglib.Internal.Ownership.Used (Budget) = 0, "all releases did not clear budget");

      Outcome := Jpeglib.Internal.Ownership.Reserve (Budget, Jpeglib.Byte_Count'Last, Jpeglib.Byte_Count'Last, First);
      Assert (Jpeglib.Results.Succeeded (Outcome), "max reservation failed");
      Outcome := Jpeglib.Internal.Ownership.Reserve (Budget, Jpeglib.Byte_Count'Last, 1, Second);
      Assert (not Jpeglib.Results.Succeeded (Outcome), "overflowing reservation succeeded");
      Assert
        (Outcome.First_Error.Code = Jpeglib.Errors.Integer_Overflow,
         "overflowing reservation used wrong error");
   end Ownership_Reservations_Are_Idempotent;

   procedure Markers_Are_Classified (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Jpeglib.Internal.Markers;
   begin
      Assert (Is_Standalone (SOI), "SOI must be standalone");
      Assert (Is_Standalone (RST3), "RST3 must be standalone");
      Assert (Restart_Number (RST7) = 7, "RST7 number mismatch");
      Assert (Has_Length (DQT), "DQT must have length");
      Assert (Has_Length (SOS), "SOS must have length");
      Assert (Is_APP (APP14), "APP14 must be APP");
      Assert (Is_Frame (SOF0), "SOF0 must be frame");
      Assert (Is_Frame (SOF2), "SOF2 must be frame");
      Assert (Is_Reserved (JPG), "JPG marker must be reserved");
      Assert (not Has_Length (EOI), "EOI must not have length");
   end Markers_Are_Classified;
end Jpeglib_Testing.Test_Core;
