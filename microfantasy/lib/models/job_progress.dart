import 'cutting_job.dart';

class JobProgress {
  JobProgress(this.job, [int index = 0])
    : index = index.clamp(0, job.steps.length - 1);
  final CuttingJob job;
  int index;
  CuttingStep get current => job.steps[index];
  void next() => index = (index + 1).clamp(0, job.steps.length - 1);
  void previous() => index = (index - 1).clamp(0, job.steps.length - 1);
}
