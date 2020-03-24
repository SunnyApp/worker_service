class RunnerInvocation {
  final int id;
  final Function function;
  final dynamic argument;

  RunnerInvocation(this.id, this.function, this.argument);
}

class RunnerInvocationResult {
  final int id;
  final dynamic result;
  final bool didExecute;
  final bool isSuccess;
  final dynamic error;

  RunnerInvocationResult.payloadFailure(this.id, this.error)
      : didExecute = false,
        isSuccess = false,
        result = null;
  RunnerInvocationResult.executionFailure(this.id, this.error)
      : didExecute = true,
        isSuccess = false,
        result = null;
  RunnerInvocationResult.success(this.id, this.result)
      : didExecute = true,
        isSuccess = true,
        error = null;
}
